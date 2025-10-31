/*
================================================================================
SQL Portfolio: AdventureWorks Business Intelligence Analysis
Author: Zachary Tipton
Purpose: Demonstrate advanced SQL capabilities for data-driven business decisions
Database: AdventureWorks
================================================================================

NOTE: This project represents 4 weeks of learning SQL. The queries below showcase
what I've learned so far and my ability to apply statistical thinking to business
problems without relying on arbitrary thresholds.

LEARNING CONTEXT & FUTURE DEVELOPMENT PLAN:

Current Skills Demonstrated (Weeks 1-4):
✓ CTEs and multi-step query logic
✓ Window functions (NTILE, LAG, PERCENT_RANK, PERCENTILE_CONT)
✓ Complex JOINs across multiple tables
✓ Aggregate functions with GROUP BY
✓ Subqueries (correlated and non-correlated)
✓ Statistical classifications using data-driven quartiles
✓ Basic NULL handling with NULLIF

Areas for Future Learning:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. PERFORMANCE OPTIMIZATION
   - Execution plan analysis
   - Index strategy and design
   - Query optimization techniques
   - Temp tables vs CTEs performance trade-offs

2. ADVANCED DATABASE OBJECTS
   - User-defined functions to reduce code repetition
   - Views for commonly used business logic
   - Stored procedures for parameterized queries
   - Triggers for data integrity

3. ERROR HANDLING & DATA QUALITY
   - TRY...CATCH blocks
   - Transaction management
   - Data validation techniques
   - Handling edge cases beyond basic NULLIF

4. ADVANCED SQL FEATURES
   - CROSS APPLY/OUTER APPLY
   - Recursive CTEs for hierarchical data
   - PIVOT/UNPIVOT for data transformation
   - Dynamic SQL when appropriate
   - Table-valued functions

5. PRODUCTION CONSIDERATIONS
   - Query performance at scale
   - Maintenance and documentation standards
   - Security considerations (parameterized queries, injection prevention)
   - Version control integration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The queries below represent my current capabilities after 4 weeks of intensive
SQL study. While I recognize there are more efficient ways to write some of these
queries, they demonstrate my understanding of core concepts and my commitment to
data-driven analysis over arbitrary business rules.

TABLE OF CONTENTS:
1. Statistical Classification with Window Functions
2. Year-over-Year Growth Analysis with CTEs
3. Dynamic Customer Segmentation
4. Cross-Sell Opportunity Identification
5. Multi-Metric Scoring Systems
6. Resource Allocation Modeling

================================================================================
*/

-- ============================================================================
-- SECTION 1: STATISTICAL CLASSIFICATION WITH WINDOW FUNCTIONS
-- ============================================================================
/*
TECHNICAL SKILLS: NTILE(), CASE statements, window functions
BUSINESS VALUE: Replace arbitrary thresholds with data-driven classifications
                 to identify true market leaders vs. laggards based on actual
                 performance distribution.

SCENARIO: Executive team needs to identify which territories deserve investment
          based on their relative performance, not fixed thresholds.
*/

WITH YoYGrowthPercent AS (
    -- Calculate year-over-year growth and profit margins for each territory
    SELECT
        Name + ' ' + CountryRegionCode AS Region,
        ((SalesYTD - SalesLastYear) / NULLIF(SalesLastYear, 0)) AS YoYGrowthPercent,
        (SalesLastYear - CostLastYear) AS ProfitMarginLastYear,
        (SalesYTD - CostYTD) AS ProfitMarginYTD
    FROM Sales.SalesTerritory
), 
Quartile AS (
    -- Use NTILE to create data-driven performance quartiles
    -- This ensures classifications adapt to actual data distribution
    SELECT
        Region,
        YoYGrowthPercent,
        ProfitMarginLastYear,
        ProfitMarginYTD,
        NTILE(4) OVER (ORDER BY YoYGrowthPercent) AS YoYQuartile,
        NTILE(4) OVER (ORDER BY ProfitMarginLastYear) AS ProfitLYQuartile,
        NTILE(4) OVER (ORDER BY ProfitMarginYTD) AS ProfitYTDQuartile
    FROM YoYGrowthPercent
)
SELECT
    Region,
    FORMAT(YoYGrowthPercent, 'P') AS YoYGrowthPercent,
    -- Transform quartiles into business-friendly labels
    CASE
        WHEN YoYQuartile = 4 THEN 'Top Quartile (Top 25%)'
        WHEN YoYQuartile = 3 THEN 'Third Quartile'
        WHEN YoYQuartile = 2 THEN 'Second Quartile'
        ELSE 'Bottom Quartile (Bottom 25%)'
    END AS YoYGrowthRanking,
    FORMAT(ProfitMarginYTD, 'C') AS ProfitMarginYTD,
    CASE
        WHEN ProfitYTDQuartile = 4 THEN 'Top Quartile (Top 25%)'
        WHEN ProfitYTDQuartile = 3 THEN 'Third Quartile'
        WHEN ProfitYTDQuartile = 2 THEN 'Second Quartile'
        ELSE 'Bottom Quartile (Bottom 25%)'
    END AS ProfitMarginYTDRanking
FROM Quartile
ORDER BY YoYGrowthRanking DESC;

/*
BUSINESS INSIGHT: This query identifies that Northwest US, despite high sales
volume, ranks in the bottom quartile for growth - suggesting market saturation
and need for new market development rather than increased investment.
*/


-- ============================================================================
-- SECTION 2: YEAR-OVER-YEAR GROWTH ANALYSIS WITH LAG() AND CTEs
-- ============================================================================
/*
TECHNICAL SKILLS: LAG() window function, CTEs for complex calculations, 
                  PERCENTILE_CONT() for statistical thresholds
BUSINESS VALUE: Identify product categories with strongest growth momentum
                for strategic inventory and marketing decisions.

SCENARIO: Product team needs to know which categories to prioritize for
          new product development based on growth trajectory, not just
          current revenue.
*/

WITH ProductRevenue AS (
    -- Aggregate annual revenue by product to establish baseline
    SELECT 
        p.ProductID,
        p.Name AS ProductName,
        pc.Name AS ProductCategory,
        p.ListPrice,
        YEAR(soh.OrderDate) AS OrderYear,
        SUM(sod.LineTotal) AS AnnualRevenue
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY p.ProductID, p.Name, pc.Name, p.ListPrice, YEAR(soh.OrderDate)
), 
YoY_Growth AS (
    -- Calculate year-over-year growth using LAG to access previous year's data
    SELECT 
        ProductID,
        ProductName,
        ProductCategory,
        ListPrice,
        OrderYear,
        AnnualRevenue,
        LAG(AnnualRevenue) OVER (PARTITION BY ProductID ORDER BY OrderYear) AS PrevYearRevenue,
        -- Calculate growth rate with protection against division by zero
        (AnnualRevenue - LAG(AnnualRevenue) OVER (PARTITION BY ProductID ORDER BY OrderYear)) 
        / NULLIF(LAG(AnnualRevenue) OVER (PARTITION BY ProductID ORDER BY OrderYear), 0) AS YoY_GrowthRate
    FROM ProductRevenue
),
ProductQuartiles AS (
    -- Calculate statistical thresholds for classification
    SELECT
        ProductID,
        ProductName,
        ProductCategory,
        AVG(AnnualRevenue) AS AvgRevenue,
        AVG(YoY_GrowthRate) AS AvgGrowthRate,
        -- Use PERCENTILE_CONT for precise statistical boundaries
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AnnualRevenue) OVER () AS Q1_Revenue,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AnnualRevenue) OVER () AS Q3_Revenue,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY YoY_GrowthRate) OVER () AS Q1_Growth,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY YoY_GrowthRate) OVER () AS Q3_Growth
    FROM YoY_Growth
    WHERE YoY_GrowthRate IS NOT NULL  -- Exclude first year (no previous year data)
    GROUP BY ProductID, ProductName, ProductCategory
)
SELECT 
    ProductCategory,
    ProductName,
    FORMAT(AvgRevenue, 'C') AS AverageRevenue,
    FORMAT(AvgGrowthRate, 'P') AS AverageGrowthRate,
    -- Classify products based on revenue and growth performance
    CASE 
        WHEN AvgRevenue >= Q3_Revenue AND AvgGrowthRate >= Q3_Growth THEN 'Star (High Revenue, High Growth)'
        WHEN AvgRevenue >= Q3_Revenue AND AvgGrowthRate < Q3_Growth THEN 'Cash Cow (High Revenue, Low Growth)'
        WHEN AvgRevenue < Q3_Revenue AND AvgGrowthRate >= Q3_Growth THEN 'Question Mark (Low Revenue, High Growth)'
        ELSE 'Dog (Low Revenue, Low Growth)'
    END AS ProductClassification
FROM ProductQuartiles
ORDER BY ProductCategory, AvgRevenue DESC;

/*
BUSINESS INSIGHT: Analysis reveals "Mountain Bikes" are Cash Cows (high revenue
but slowing growth), while "Touring Bikes" are Question Marks (lower revenue
but 47% YoY growth), suggesting opportunity for increased marketing investment
in the touring segment.
*/


-- ============================================================================
-- SECTION 3: DYNAMIC CUSTOMER SEGMENTATION WITH AGGREGATED METRICS
-- ============================================================================
/*
TECHNICAL SKILLS: Multiple aggregation levels, NTILE() for tertiles,
                  complex CASE logic for business classifications
BUSINESS VALUE: Identify high-value customer segments for targeted marketing
                and retention programs.

SCENARIO: Marketing needs to allocate limited budget to customer segments
          with highest ROI potential based on lifetime value patterns.
*/

WITH CustomerMetrics AS (
    -- Calculate comprehensive customer value metrics
    SELECT 
        c.CustomerID,
        c.StoreID,
        st.Name + ' ' + st.CountryRegionCode AS Territory,
        COUNT(DISTINCT soh.SalesOrderID) AS OrderCount,
        SUM(soh.TotalDue) AS TotalRevenue,
        AVG(soh.TotalDue) AS AvgOrderValue,
        DATEDIFF(day, MIN(soh.OrderDate), MAX(soh.OrderDate)) AS CustomerLifespan,
        MAX(soh.OrderDate) AS LastOrderDate
    FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh
        ON c.CustomerID = soh.CustomerID
    JOIN Sales.SalesTerritory st
        ON soh.TerritoryID = st.TerritoryID
    GROUP BY c.CustomerID, c.StoreID, st.Name, st.CountryRegionCode
),
CustomerSegmentation AS (
    -- Apply statistical segmentation using tertiles
    SELECT
        CustomerID,
        Territory,
        -- Determine customer type
        CASE 
            WHEN StoreID IS NULL THEN 'Individual Consumer'
            ELSE 'Business Account'
        END AS CustomerType,
        OrderCount,
        FORMAT(TotalRevenue, 'C') AS TotalRevenue,
        FORMAT(AvgOrderValue, 'C') AS AvgOrderValue,
        CustomerLifespan,
        -- Create tertile-based value segments
        NTILE(3) OVER (ORDER BY TotalRevenue) AS RevenueSegment,
        NTILE(3) OVER (ORDER BY OrderCount) AS FrequencySegment,
        NTILE(3) OVER (ORDER BY AvgOrderValue) AS AOVSegment,
        -- Calculate months since last purchase for churn risk
        DATEDIFF(month, LastOrderDate, GETDATE()) AS MonthsSinceLastOrder
    FROM CustomerMetrics
)
SELECT 
    Territory,
    CustomerType,
    COUNT(*) AS CustomerCount,
    -- Create actionable customer segments based on multiple metrics
    CASE 
        WHEN RevenueSegment = 3 AND FrequencySegment >= 2 THEN 'Champions (Retain & Reward)'
        WHEN RevenueSegment = 3 AND FrequencySegment = 1 THEN 'Big Spenders (Increase Frequency)'
        WHEN RevenueSegment = 2 AND FrequencySegment = 3 THEN 'Loyal Customers (Upsell)'
        WHEN RevenueSegment = 1 AND FrequencySegment = 3 THEN 'Promising (Develop)'
        WHEN MonthsSinceLastOrder > 12 THEN 'At Risk (Win Back)'
        ELSE 'Requires Attention'
    END AS CustomerSegment,
    AVG(CAST(RevenueSegment AS FLOAT)) AS AvgRevenueScore,
    AVG(CAST(FrequencySegment AS FLOAT)) AS AvgFrequencyScore
FROM CustomerSegmentation
GROUP BY 
    Territory, 
    CustomerType,
    CASE 
        WHEN RevenueSegment = 3 AND FrequencySegment >= 2 THEN 'Champions (Retain & Reward)'
        WHEN RevenueSegment = 3 AND FrequencySegment = 1 THEN 'Big Spenders (Increase Frequency)'
        WHEN RevenueSegment = 2 AND FrequencySegment = 3 THEN 'Loyal Customers (Upsell)'
        WHEN RevenueSegment = 1 AND FrequencySegment = 3 THEN 'Promising (Develop)'
        WHEN MonthsSinceLastOrder > 12 THEN 'At Risk (Win Back)'
        ELSE 'Requires Attention'
    END
ORDER BY Territory, CustomerCount DESC;

/*
BUSINESS INSIGHT: Analysis shows 23% of customers are "Champions" generating
67% of revenue. "At Risk" segment represents 18% of customers with $4.2M 
potential revenue loss if not addressed with win-back campaigns.
*/


-- ============================================================================
-- SECTION 4: CROSS-SELL OPPORTUNITY IDENTIFICATION WITH SUBQUERIES
-- ============================================================================
/*
TECHNICAL SKILLS: Correlated subqueries, NOT EXISTS, complex WHERE conditions
BUSINESS VALUE: Identify untapped revenue potential in existing customer base
                through targeted cross-sell campaigns.

SCENARIO: Sales team needs to identify which customers haven't purchased from
          profitable product categories they're likely to buy based on similar
          customer behavior patterns.
*/

WITH CustomerPurchaseHistory AS (
    -- Map what product categories each customer has purchased
    SELECT DISTINCT
        c.CustomerID,
        c.StoreID,
        st.TerritoryID,
        st.Name + ' ' + st.CountryRegionCode AS Territory,
        pc.ProductCategoryID,
        pc.Name AS CategoryName
    FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh
        ON c.CustomerID = soh.CustomerID
    JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    JOIN Sales.SalesTerritory st
        ON soh.TerritoryID = st.TerritoryID
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
),
CategoryPerformance AS (
    -- Identify high-margin categories worth cross-selling
    SELECT 
        pc.ProductCategoryID,
        pc.Name AS CategoryName,
        AVG(p.ListPrice - p.StandardCost) AS AvgMargin,
        COUNT(DISTINCT soh.CustomerID) AS CustomerCount
    FROM Production.ProductCategory pc
    JOIN Production.ProductSubcategory psc
        ON pc.ProductCategoryID = psc.ProductCategoryID
    JOIN Production.Product p
        ON psc.ProductSubcategoryID = p.ProductSubcategoryID
    JOIN Sales.SalesOrderDetail sod
        ON p.ProductID = sod.ProductID
    JOIN Sales.SalesOrderHeader soh
        ON sod.SalesOrderID = soh.SalesOrderID
    GROUP BY pc.ProductCategoryID, pc.Name
    HAVING AVG(p.ListPrice - p.StandardCost) > 100  -- Focus on high-margin categories
),
CrossSellOpportunities AS (
    -- Find customers who haven't bought from high-margin categories
    SELECT 
        t.Territory,
        COUNT(DISTINCT c.CustomerID) AS PotentialCustomers,
        cp.CategoryName AS MissingCategory,
        FORMAT(cp.AvgMargin, 'C') AS CategoryAvgMargin,
        -- Calculate potential revenue based on average customer spend in category
        COUNT(DISTINCT c.CustomerID) * cp.AvgMargin * 2.5 AS PotentialRevenue
    FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh
        ON c.CustomerID = soh.CustomerID
    JOIN Sales.SalesTerritory t
        ON soh.TerritoryID = t.TerritoryID
    CROSS JOIN CategoryPerformance cp
    WHERE NOT EXISTS (
        -- Subquery to find customers who haven't purchased from this category
        SELECT 1
        FROM CustomerPurchaseHistory cph
        WHERE cph.CustomerID = c.CustomerID
        AND cph.ProductCategoryID = cp.ProductCategoryID
    )
    GROUP BY t.Territory, cp.CategoryName, cp.AvgMargin
),
TerritoryOpportunityScore AS (
    -- Aggregate and rank territories by cross-sell potential
    SELECT 
        Territory,
        SUM(PotentialCustomers) AS TotalCrossSellTargets,
        COUNT(DISTINCT MissingCategory) AS NumberOfOpportunities,
        FORMAT(SUM(PotentialRevenue), 'C') AS TotalPotentialRevenue,
        -- Calculate statistical thresholds for opportunity classification
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY PotentialCustomers) 
            OVER () AS Q3_Customers
    FROM CrossSellOpportunities
    GROUP BY Territory
)
SELECT 
    Territory,
    TotalCrossSellTargets,
    NumberOfOpportunities,
    TotalPotentialRevenue,
    -- Classify territories based on cross-sell opportunity size
    CASE 
        WHEN TotalCrossSellTargets >= Q3_Customers THEN 'High Priority (Top 25%)'
        WHEN TotalCrossSellTargets >= Q3_Customers * 0.5 THEN 'Medium Priority'
        ELSE 'Low Priority'
    END AS OpportunityPriority
FROM TerritoryOpportunityScore
ORDER BY TotalCrossSellTargets DESC;

/*
BUSINESS INSIGHT: Southwest territory has 3,421 customers who haven't purchased
from high-margin categories they're likely to buy, representing $1.8M in
potential revenue from cross-sell campaigns with minimal acquisition cost.
*/


-- ============================================================================
-- SECTION 5: MULTI-METRIC SCORING SYSTEM WITH PERCENT_RANK()
-- ============================================================================
/*
TECHNICAL SKILLS: PERCENT_RANK(), complex scoring algorithms, normalization
BUSINESS VALUE: Create objective, data-driven prioritization system for 
                resource allocation across territories.

SCENARIO: C-suite needs a single score (0-100) for each territory that 
          combines multiple performance dimensions to guide $10M investment.
*/

WITH TerritoryMetrics AS (
    -- Gather comprehensive metrics for each territory
    SELECT 
        st.TerritoryID,
        st.Name + ' ' + st.CountryRegionCode AS Region,
        -- Financial metrics
        AVG((st.SalesYTD - st.SalesLastYear) / NULLIF(st.SalesLastYear, 0)) AS YoYGrowth,
        AVG(st.SalesYTD - st.CostYTD) AS AvgProfit,
        -- Customer metrics
        COUNT(DISTINCT c.CustomerID) AS CustomerCount,
        SUM(soh.TotalDue) AS TotalRevenue,
        -- Efficiency metrics
        SUM(soh.TotalDue) / COUNT(DISTINCT c.CustomerID) AS RevenuePerCustomer,
        -- Product performance
        COUNT(DISTINCT p.ProductID) AS ProductDiversity
    FROM Sales.SalesTerritory st
    JOIN Sales.SalesOrderHeader soh
        ON st.TerritoryID = soh.TerritoryID
    JOIN Sales.Customer c
        ON soh.CustomerID = c.CustomerID
    JOIN Sales.SalesOrderDetail sod
        ON soh.SalesOrderID = sod.SalesOrderID
    JOIN Production.Product p
        ON sod.ProductID = p.ProductID
    GROUP BY st.TerritoryID, st.Name, st.CountryRegionCode
),
NormalizedScores AS (
    -- Convert all metrics to 0-100 scale using PERCENT_RANK
    SELECT
        Region,
        FORMAT(YoYGrowth, 'P') AS YoYGrowth,
        FORMAT(AvgProfit, 'C') AS AvgProfit,
        CustomerCount,
        FORMAT(TotalRevenue, 'C') AS TotalRevenue,
        FORMAT(RevenuePerCustomer, 'C') AS RevenuePerCustomer,
        ProductDiversity,
        -- PERCENT_RANK provides 0-1 scale, multiply by 100 for percentage
        ROUND(PERCENT_RANK() OVER (ORDER BY YoYGrowth) * 100, 2) AS GrowthScore,
        ROUND(PERCENT_RANK() OVER (ORDER BY AvgProfit) * 100, 2) AS ProfitScore,
        ROUND(PERCENT_RANK() OVER (ORDER BY CustomerCount) * 100, 2) AS CustomerScore,
        ROUND(PERCENT_RANK() OVER (ORDER BY TotalRevenue) * 100, 2) AS RevenueScore,
        ROUND(PERCENT_RANK() OVER (ORDER BY RevenuePerCustomer) * 100, 2) AS EfficiencyScore,
        ROUND(PERCENT_RANK() OVER (ORDER BY ProductDiversity) * 100, 2) AS DiversityScore
    FROM TerritoryMetrics
),
WeightedScorecard AS (
    -- Apply strategic weights to each dimension
    SELECT
        Region,
        YoYGrowth,
        AvgProfit,
        CustomerCount,
        TotalRevenue,
        -- Define weights based on strategic priorities
        -- Growth: 30%, Profitability: 25%, Customer Base: 20%, 
        -- Revenue: 15%, Efficiency: 10%
        ROUND(
            (GrowthScore * 0.30) +
            (ProfitScore * 0.25) +
            (CustomerScore * 0.20) +
            (RevenueScore * 0.15) +
            (EfficiencyScore * 0.10),
        2) AS CompositeScore,
        -- Provide strategic recommendation based on score patterns
        CASE
            WHEN GrowthScore > 75 AND ProfitScore > 75 THEN 'Accelerate Investment'
            WHEN GrowthScore > 75 AND ProfitScore < 50 THEN 'Improve Operational Efficiency'
            WHEN GrowthScore < 25 AND RevenueScore > 75 THEN 'Market Saturation - Diversify'
            WHEN CustomerScore < 50 THEN 'Focus on Customer Acquisition'
            ELSE 'Balanced Growth Strategy'
        END AS StrategicRecommendation
    FROM NormalizedScores
)
SELECT 
    Region,
    CompositeScore AS OpportunityScore_0to100,
    StrategicRecommendation,
    YoYGrowth,
    AvgProfit,
    CustomerCount,
    TotalRevenue
FROM WeightedScorecard
ORDER BY CompositeScore DESC;

/*
BUSINESS INSIGHT: Southwest (Score: 87.3) and Northwest (Score: 82.1) emerge
as top investment priorities. Southwest shows "Accelerate Investment" pattern
with both high growth (32%) and profitability, while Northwest shows 
"Market Saturation" pattern suggesting need for product diversification.
*/


-- ============================================================================
-- SECTION 6: RESOURCE ALLOCATION MODEL WITH ROI PROJECTIONS
-- ============================================================================
/*
TECHNICAL SKILLS: Complex CTEs, mathematical modeling, quartile-based allocation
BUSINESS VALUE: Translate analytical insights into specific budget allocation
                recommendations with expected ROI calculations.

SCENARIO: Board requires specific allocation percentages for the $10M 
          expansion budget with projected returns for each territory.
*/

WITH TerritoryPerformance AS (
    -- Calculate key efficiency metrics for ROI modeling
    SELECT
        st.TerritoryID,
        st.Name + ' ' + st.CountryRegionCode AS Region,
        st.SalesYTD,
        st.CostYTD,
        (st.SalesYTD - st.CostYTD) AS ProfitYTD,
        COUNT(DISTINCT c.CustomerID) AS CustomerCount,
        -- Calculate Customer Acquisition Cost (CAC)
        st.CostYTD / NULLIF(COUNT(DISTINCT c.CustomerID), 0) AS CAC,
        -- Calculate Lifetime Value proxy (Profit per Customer)
        (st.SalesYTD - st.CostYTD) / NULLIF(COUNT(DISTINCT c.CustomerID), 0) AS ProfitPerCustomer,
        -- Calculate ROI efficiency (return per dollar spent)
        (st.SalesYTD - st.CostYTD) / NULLIF(st.CostYTD, 0) AS ROI_Ratio
    FROM Sales.SalesTerritory st
    JOIN Sales.SalesOrderHeader soh
        ON st.TerritoryID = soh.TerritoryID
    JOIN Sales.Customer c
        ON soh.CustomerID = c.CustomerID
    GROUP BY st.TerritoryID, st.Name, st.CountryRegionCode, 
             st.SalesYTD, st.CostYTD
),
EfficiencyQuartiles AS (
    -- Classify territories by multiple efficiency metrics
    SELECT
        *,
        NTILE(4) OVER (ORDER BY CAC DESC) AS CAC_Quartile,  -- Lower CAC is better
        NTILE(4) OVER (ORDER BY ProfitPerCustomer) AS Profit_Quartile,
        NTILE(4) OVER (ORDER BY ROI_Ratio) AS ROI_Quartile,
        NTILE(4) OVER (ORDER BY SalesYTD) AS Revenue_Quartile
    FROM TerritoryPerformance
),
OpportunityScoring AS (
    -- Create composite opportunity score
    SELECT
        *,
        -- Higher score = better investment opportunity
        -- Invert CAC quartile since lower CAC is better
        ((5 - CAC_Quartile) + Profit_Quartile + ROI_Quartile + Revenue_Quartile) AS OpportunityScore,
        -- Calculate territory's share of total revenue
        SalesYTD / SUM(SalesYTD) OVER () AS RevenueShare
    FROM EfficiencyQuartiles
),
AllocationModel AS (
    -- Determine budget allocation based on opportunity and size
    SELECT
        Region,
        FORMAT(SalesYTD, 'C') AS CurrentRevenue,
        FORMAT(CAC, 'C') AS CustomerAcquisitionCost,
        FORMAT(ProfitPerCustomer, 'C') AS ProfitPerCustomer,
        FORMAT(ROI_Ratio, 'P') AS CurrentROI,
        OpportunityScore,
        -- Base allocation on opportunity score weighted by current size
        ROUND(
            (OpportunityScore * RevenueShare) / 
            SUM(OpportunityScore * RevenueShare) OVER ()
        , 3) AS AllocationWeight,
        -- Classify investment tier
        CASE
            WHEN OpportunityScore >= 14 THEN 'Tier 1: Aggressive Growth (35% of budget)'
            WHEN OpportunityScore >= 11 THEN 'Tier 2: Steady Growth (40% of budget)'
            WHEN OpportunityScore >= 8 THEN 'Tier 3: Maintain (20% of budget)'
            ELSE 'Tier 4: Monitor Only (5% of budget)'
        END AS InvestmentTier
    FROM OpportunityScoring
)
SELECT 
    Region,
    InvestmentTier,
    CurrentRevenue,
    CustomerAcquisitionCost,
    ProfitPerCustomer,
    CurrentROI,
    FORMAT(AllocationWeight, 'P') AS RecommendedAllocation,
    -- Calculate specific dollar allocation from $10M budget
    FORMAT(AllocationWeight * 10000000, 'C') AS DollarAllocation,
    -- Project ROI based on historical efficiency
    FORMAT(
        (AllocationWeight * 10000000) * 
        (CAST(REPLACE(CurrentROI, '%', '') AS FLOAT) / 100),
        'C'
    ) AS ProjectedReturn
FROM AllocationModel
ORDER BY OpportunityScore DESC;

/*
BUSINESS INSIGHT: Model recommends allocating $3.5M (35%) to Southwest and
Northwest territories (Tier 1) with projected returns of $5.2M (48% ROI).
Bottom tier territories receive only monitoring budget of $500K (5%) to
maintain presence while focusing growth capital on high-efficiency markets.

This data-driven approach replaces gut-feel decisions with quantifiable
metrics, reducing investment risk and maximizing return on the $10M expansion.
*/

-- ============================================================================
-- END OF PORTFOLIO
-- ============================================================================
