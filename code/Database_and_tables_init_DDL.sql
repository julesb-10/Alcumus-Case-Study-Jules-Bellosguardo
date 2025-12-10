/*
  ====================================================================================================================================
  
  This Code simply Initializes a Database and the appropriate tables that CSVs were to be imported into

====================================================================================================================================
*/




DROP DATABASE IF EXISTS alcumus_project;
CREATE DATABASE alcumus_project;


-- Staging: Renewing Customers
DROP TABLE IF EXISTS stg_RenewingCustomers;
CREATE TABLE stg_RenewingCustomers (
    CoRef VARCHAR(50),
    RenewalDate VARCHAR(50),
    Employees VARCHAR(20),
    Product VARCHAR(100),
    ProspectStatus VARCHAR(100),
    ProspectOutcome VARCHAR(50),
    Clients VARCHAR(20),
    Price VARCHAR(20)
);



-- Staging: Supplemental Data
DROP TABLE IF EXISTS stg_SupplementalData;
CREATE TABLE stg_SupplementalData (
    CoRef VARCHAR(50),
    RegistrationDate VARCHAR(50),
    SSIPMember VARCHAR(50),
    CompanyType VARCHAR(100),
    IndustrySector VARCHAR(200)
);


-- Staging: Price List
DROP TABLE IF EXISTS stg_PriceList;
CREATE TABLE stg_PriceList (
    Band VARCHAR(50),
    Price VARCHAR(50)
);



-- Staging: Current Live Customers
DROP TABLE IF EXISTS stg_CurrentLiveCustomers;
CREATE TABLE stg_CurrentLiveCustomers (
    CoRef VARCHAR(50),
    SubsidiaryType VARCHAR(50),
    NoOfSubsidiaries INT,
    HoldingCoref VARCHAR(50),
    NoOfAnchorings INT,
    AccountStage VARCHAR(50),
    AccountStageDate DATE,
    MembershipStatus VARCHAR(50),
    RegistrationDate DATE,
    RenewalDate DATE,
    AuditStatus VARCHAR(200),
    AuditStatusDate DATE,
    Package VARCHAR(50),
    Band VARCHAR(50),
    Tenure INT,
    Price DECIMAL(10,2) NULL
);



