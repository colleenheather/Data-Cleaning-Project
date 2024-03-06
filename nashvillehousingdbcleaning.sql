Notes: 

-- General Clean Up

DELIMITER //
create procedure fixData(table_name TEXT, column_name TEXT, data_type TEXT)
BEGIN
    SET @sql = CONCAT('UPDATE ', table_name , ' SET ', column_name, ' = NULL WHERE ', column_name, ' = ""');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

	SET @sql = CONCAT('alter table ', table_name , ' modify column ', column_name, " ",  data_type);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

alter table nashvillehousing
CHANGE ï»¿UniqueID UniqueID TEXT;


call fixData('nashvillehousing', 'acreage', 'double');
call fixData('nashvillehousing', 'landvalue', 'int');
call fixData('nashvillehousing', 'buildingvalue', 'int');
call fixData('nashvillehousing', 'totalvalue', 'int');
call fixData('nashvillehousing', 'yearbuilt', 'int');
call fixData('nashvillehousing', 'bedrooms', 'int');
call fixData('nashvillehousing', 'fullbath', 'int');
call fixData('nashvillehousing', 'halfbath', 'int');

call fixData('nashvillehousing', 'OwnerName', 'text');
call fixData('nashvillehousing', 'OwnerSplitAddress', 'text');
call fixData('nashvillehousing', 'OwnerSplitCity', 'text');
call fixData('nashvillehousing', 'OwnerSplitState', 'text');

DELIMITER //
create procedure trimColumn(table_name TEXT, column_name TEXT)
BEGIN
    SET @sql = CONCAT('UPDATE ', table_name , ' SET ', column_name, ' = TRIM(', column_name, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;


call trimColumn('nashvillehousing', 'landuse');
call trimColumn('nashvillehousing', 'saleprice');
call trimColumn('nashvillehousing', 'legalreference');
call trimColumn('nashvillehousing', 'soldasvacant');
call trimColumn('nashvillehousing', 'ownername');
call trimColumn('nashvillehousing', 'ownersplitaddress');
call trimColumn('nashvillehousing', 'ownersplitcity');
call trimColumn('nashvillehousing', 'ownersplitstate');


---------------------------------------------------------------------------------------------

-- Standardize Date Format 
-- from TEXT ‘April 9, 2013’ to DATE ‘2013-04-09’

alter table nashvillehousing
add column new_date DATE after propertyaddress;

update nashvillehousing
SET new_date = DATE_FORMAT(STR_TO_DATE(saledate, '%M %e, %Y'), '%Y-%m-%d');

alter table nashvillehousing drop SaleDate;

alter table nashvillehousing 
change column new_date SaleDate DATE;

-----------------------------------------------------------------------------------------

-- Populate Property Address data
-- looking for doubles of ParcelID, if there is a double where one has a PropertyAddress and the other doesn’t, populate the empty address

select a.parcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, IF(LENGTH(a.propertyAddress) = 0, b.propertyAddress, a.propertyAddress)
from nashvillehousing a
join nashvillehousing b
	on a.parcelid = b.ParcelID
    AND a.UniqueID != b.UniqueID
where a.propertyaddress = '';

-- IF(LENGTH(column_name) = 0, ‘value to add if empty’, column_name)

update nashvillehousing a
join nashvillehousing b
	on a.parcelid = b.ParcelID
    AND a.UniqueID != b.UniqueID
set a.propertyaddress = IF(LENGTH(a.propertyAddress) = 0, b.propertyAddress, a.propertyAddress)
where LENGTH(a.propertyaddress) = 0;

---------------------------------------------------------------------------------------------

-- Breaking out address into individual columns (address, city, state)
-- substring and INSTR() instead of CHARINDEX()[sql]
-- breaking up PropertyAddress and OwnerAddress column 

-- propertyaddress
select
substring(PropertyAddress, 1, INSTR(PropertyAddress, ',') -1) as address,
substring(PropertyAddress, INSTR(PropertyAddress, ',') +1, length(propertyaddress)) as address2
from nashvillehousing;

alter table nashvillehousing
add column PropertySplitAddress nvarchar(255)
after PropertyAddress;

alter table nashvillehousing
add column PropertySplitCity nvarchar(255)
after PropertySplitAddress;

set sql_safe_updates = 0;

update nashvillehousing
set PropertySplitAddress = substring(PropertyAddress, 1, INSTR(PropertyAddress, ',') -1);

update nashvillehousing
set propertySplitCity = substring(PropertyAddress, INSTR(PropertyAddress, ',') +1, length(propertyaddress));



--owner address
select trim(substring_index(OwnerAddress, ',', 1)) as part1
from nashvillehousing;

select trim(substring_index(substring_index(owneraddress, ',', 2), ',', -1)) as part2
from nashvillehousing;

select trim(substring_index(OwnerAddress, ',', -1)) as part3
from nashvillehousing;


alter table nashvillehousing
add column OwnerSplitAddress TEXT
after OwnerAddress;

alter table nashvillehousing
add column OwnerSplitCity TEXT
after OwnerSplitAddress;

alter table nashvillehousing
add column OwnerSplitState text
after OwnerSplitCity;

update nashvillehousing
set OwnerSplitAddress = trim(substring_index(OwnerAddress, ',', 1));

update nashvillehousing
set OwnerSplitCity = trim(substring_index(substring_index(owneraddress, ',', 2), ',', -1))
;

update nashvillehousing
set OwnerSplitState = trim(substring_index(OwnerAddress, ',', -1))
;

---------------------------------------------------------------------------------------
-- Change Y and N to Yes and No in ‘Sold as Vacant’ field

select distinct(SoldAsVacant), Count(SoldAsVacant)
from nashvillehousing
Group by SoldAsVacant
Order by 2;

select SoldAsVacant,
CASE when SoldAsVacant = 'Y' THEN 'Yes'
	when SoldAsVacant = 'N' THEN 'No'
    else SoldAsVacant
    end
from nashvillehousing;

update nashvillehousing
set SoldAsVacant = CASE when SoldAsVacant = 'Y' THEN 'Yes'
	when SoldAsVacant = 'N' THEN 'No'
    else SoldAsVacant
    end;
    
select distinct(SoldAsVacant), Count(SoldAsVacant)
from nashvillehousing
Group by SoldAsVacant
order by 2;

-------------------------------------------------------------------------------------------

-- Remove duplicates 

-- checking values to delete 
 WITH RowNumCTE as (
select *, 
	row_number() Over(
    partition by parcelID,
				PropertyAddress,
                saleprice,
                saledate,
                LegalReference
                order by
					UniqueID) row_num
from nashvillehousing
order by ParcelID)
select * from RowNumCTE
where row_num > 1;


DELETE nh1 FROM nashvillehousing nh1
JOIN (
    SELECT 
        parcelID,
        PropertyAddress,
        saleprice,
        saledate,
        LegalReference,
        ROW_NUMBER() OVER (
            PARTITION BY parcelID, PropertyAddress, saleprice, saledate, LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM nashvillehousing
) nh2 ON nh1.parcelID = nh2.parcelID
    AND nh1.PropertyAddress = nh2.PropertyAddress
    AND nh1.saleprice = nh2.saleprice
    AND nh1.saledate = nh2.saledate
    AND nh1.LegalReference = nh2.LegalReference
WHERE nh2.row_num > 1;

-----------------------------------------------------------------------------------------

-- Delete Unused Columns

alter table nashvillehousing
drop column OwnerAddress, 
drop column TaxDistrict, 
drop column PropertyAddress,
drop column saledate;
