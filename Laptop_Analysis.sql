USE laptops;

/* Question 1: Rank the top 5 laptops with the highest CPU benchmark scores, including information 
about the processor, GPU, and screen resolution. */

SELECT 
    L.Laptop_ID,
    C.Processor_Name,
    L.Brand,
    G.gpu_name,
    R.Resolution,
    C.CPU_Mark,
    DENSE_RANK() OVER (ORDER BY C.CPU_Mark DESC) AS Ranking
FROM 
    laptops L
JOIN cpu C ON L.Processor_ID = C.Processor_ID
JOIN gpuclass G ON L.gpu_name = G.gpu_name
JOIN Resolution R ON L.Resolution_ID = R.Resolution_ID
ORDER BY 
    C.CPU_Mark DESC
LIMIT 5;

# Question 2: Determine the percentage distribution of laptops across different USB types for each brand.
SELECT 
    L.Brand,
    USB_Type,
    COUNT(*) AS Total_Laptops,
    (COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY Brand)) AS Percentage
FROM 
    Laptops L
JOIN USB U ON L.USB_ID = U.USB_ID
GROUP BY 
    Brand, USB_Type;

/* Question 3: What is the average screen size of laptops for each GPU class, and how does it compare to 
the overall average screen size? */
WITH AverageScreenSize AS (
    SELECT AVG(Screen_Size) AS Overall_Avg
    FROM Laptops
)
SELECT 
    G.GPU_Class,
    AVG(L.Screen_Size) AS Avg_Screen_Size,
    (SELECT Overall_Avg FROM AverageScreenSize) AS Overall_Avg
FROM Laptops L
JOIN gpuclass G ON L.GPU_name = G.GPU_name
GROUP BY G.GPU_Class
ORDER BY G.GPU_Class;

/* Question 4: Find the top 3 USB types with the highest number of laptops and the percentage they contribute 
to the total, considering only laptops with UHD, FHD, UHDPLUS and FHDPLUS resolution. */

WITH ResolutionFilter AS (
    SELECT 
        Laptop_ID
    FROM 
        Laptops L
    JOIN Resolution R ON L.Resolution_ID = R.Resolution_ID
    WHERE 
        R.Resolution IN ('UHD', 'FHD', 'UHDPLUS', 'FHDPLUS')
),
USBCounts AS (
    SELECT 
        U.USB_Type,
        COUNT(*) AS Laptop_Count
    FROM 
        ResolutionFilter RF
    JOIN Laptops L ON RF.Laptop_ID = L.Laptop_ID
    JOIN USB U ON L.USB_ID = U.USB_ID
    GROUP BY 
        U.USB_Type
)
SELECT 
    USB_Type,
    Laptop_Count,
    (Laptop_Count * 100.0 / SUM(Laptop_Count) OVER ()) AS Percentage
FROM 
    USBCounts
ORDER BY 
    Laptop_Count DESC
LIMIT 3;

/* Question 5: Identify the top 3 resolutions with the lowest average RAM capacity for laptops, and provide 
the percentage of total laptops each resolution represents. */

WITH TotalLaptops AS (
    SELECT 
        COUNT(*) AS Total_Count
    FROM 
        Laptops
),
AverageRams AS (
    SELECT 
        R.Resolution,
        AVG(L.RAM) AS Avg_RAM,
        COUNT(L.Laptop_ID) AS Resolution_Count
    FROM 
        Laptops L
    JOIN Resolution R ON L.Resolution_ID = R.Resolution_ID
    GROUP BY 
        R.Resolution
)
SELECT 
    AR.Resolution,
    AR.Avg_RAM,
    AR.Resolution_Count * 100.0 / TL.Total_Count AS Resolution_Percentage
FROM 
    AverageRams AR
CROSS JOIN TotalLaptops TL
ORDER BY 
    AR.Avg_RAM
LIMIT 5;

/* Question 6: Identify the brand with the highest average storage size for laptops with a screen size larger 
than the overall average. Also, provide the cumulative percentage of total storage for all laptops. */

WITH ScreenSizeAverage AS (
    SELECT AVG(Screen_Size) AS Avg_Screen_Size
    FROM Laptops
),
NormalizedStorage AS (
    SELECT 
        Storage_ID,
        CASE
            WHEN RIGHT(Storage, 2) = 'TB' THEN CAST(LEFT(Storage, LENGTH(Storage) - 2) AS UNSIGNED) * 1024
            WHEN RIGHT(Storage, 2) = 'GB' THEN CAST(LEFT(Storage, LENGTH(Storage) - 2) AS UNSIGNED)
            ELSE NULL -- Handles unexpected data formats
        END AS Storage_GB
    FROM Storage
),
StorageTotals AS (
    SELECT SUM(Storage_GB) AS Total_Storage
    FROM NormalizedStorage
),
BrandStorage AS (
    SELECT 
        L.Brand,
        AVG(NS.Storage_GB) AS Avg_Storage_Size
    FROM 
        Laptops L
    JOIN NormalizedStorage NS ON L.Storage_ID = NS.Storage_ID
    WHERE 
        L.Screen_Size > (SELECT Avg_Screen_Size FROM ScreenSizeAverage)
    GROUP BY 
        L.Brand
)
SELECT 
    BS.Brand,
    BS.Avg_Storage_Size,
    (BS.Avg_Storage_Size * 100.0 / (SELECT Total_Storage FROM StorageTotals)) AS PercentageOfTotal
FROM 
    BrandStorage BS
ORDER BY 
    BS.Avg_Storage_Size DESC
LIMIT 1;

/* Question 7: Among refurbished laptops, what is the average price difference between those with storage 
capacity greater than 256GB and those with storage capacity 256GB or less? 
Additionally, provide the percentage distribution of these two storage */

WITH NormalizedStorage AS (
    SELECT 
        L.Laptop_ID,
        L.Price,
        L.Refurbished,
        CASE
            WHEN RIGHT(S.Storage, 2) = 'TB' THEN CAST(LEFT(S.Storage, LENGTH(S.Storage) - 2) AS UNSIGNED) * 1024
            WHEN RIGHT(S.Storage, 2) = 'GB' THEN CAST(LEFT(S.Storage, LENGTH(S.Storage) - 2) AS UNSIGNED)
            ELSE 0 -- Default for unexpected formats
        END AS Storage_GB
    FROM 
        Laptops L
    JOIN Storage S ON L.Storage_ID = S.Storage_ID
    WHERE 
        L.Refurbished = 'Yes'
),
RefurbishedStats AS (
    SELECT 
        CASE 
            WHEN Storage_GB > 256 THEN 'Greater'
            ELSE 'Lesser or Equal'
        END AS Storage_Category,
        AVG(Price) AS Avg_Price,
        COUNT(Laptop_ID) AS Count
    FROM 
        NormalizedStorage
    GROUP BY Storage_Category
)
SELECT 
    RS1.Storage_Category,
    RS1.Avg_Price - IFNULL(RS2.Avg_Price, 0) AS Price_Difference,
    RS1.Count * 100.0 / (RS1.Count + RS2.Count) AS Percentage
FROM 
    RefurbishedStats RS1
LEFT JOIN RefurbishedStats RS2 ON RS1.Storage_Category != RS2.Storage_Category;

/* Question 8: Determine the top 3 screen sizes with the highest average laptop prices, considering only laptops with 
a screen resolution of 2K and FHD. */

SELECT 
    L.Screen_Size,
    AVG(L.Price) AS Avg_Price
FROM 
    Laptops L
JOIN Resolution R ON L.Resolution_ID = R.Resolution_ID
WHERE 
    R.Resolution IN ('2K', 'QHD', 'QHDPLUS', 'FHDPLUS', 'UHD', 'UHDPLUS')
GROUP BY 
    L.Screen_Size
ORDER BY 
    Avg_Price DESC
LIMIT 3;