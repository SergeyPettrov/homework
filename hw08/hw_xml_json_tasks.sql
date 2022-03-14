/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "08 - Выборки из XML и JSON полей".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
Примечания к заданиям 1, 2:
* Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML. 
* Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
* Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
* Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server
*/


/*
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 

Опционально - если вы знакомы с insert, update, merge, то загрузить эти данные в таблицу Warehouse.StockItems.
Существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName). 
*/

declare @xmlDocument  xml

select @xmlDocument = BulkColumn
from openrowset
(bulk 'D:\HW\homework\hw08\StockItems.xml',  single_clob) as data 

select @xmlDocument as [@xmlDocument]

declare @docHandle int
exec sp_xml_preparedocument @docHandle output, @xmlDocument

select @docHandle as docHandle

drop table if exists #StockItems

create table #StockItems(
	StockItemName nvarchar (100)
	,SupplierID int
	,UnitPackageID int
	,OuterPackageID int
	,QuantityPerOuter int
	,TypicalWeightPerUnit decimal
	,LeadTimeDays int
	,IsChillerStock bit
	,TaxRate decimal
	,UnitPrice decimal
)

insert into #StockItems
select *
from openxml(@docHandle, N'/StockItems/Item')
with ( 
	StockItemName nvarchar (100) '@Name'
	,SupplierID int 'SupplierID'
	,UnitPackageID int 'Package/UnitPackageID'
	,OuterPackageID int 'Package/OuterPackageID'
	,QuantityPerOuter int 'Package/QuantityPerOuter'
	,TypicalWeightPerUnit decimal 'Package/TypicalWeightPerUnit'
	,LeadTimeDays int 'LeadTimeDays'
	,IsChillerStock bit 'IsChillerStock'
	,TaxRate decimal 'TaxRate'
	,UnitPrice decimal 'UnitPrice'
)

exec sp_xml_removedocument @docHandle

merge Warehouse.StockItems as o
using (
	select StockItemName
		,SupplierID
		,UnitPackageID
		,OuterPackageID
		,QuantityPerOuter
		,TypicalWeightPerUnit
		,LeadTimeDays
		,IsChillerStock
		,TaxRate
		,UnitPrice
	from #StockItems) as s on (o.StockItemName = s.StockItemName COLLATE Cyrillic_General_CI_AS)
when matched then
update 
	set o.SupplierID = s.SupplierID
		,o.UnitPackageID = s.UnitPackageID
		,o.OuterPackageID = s.OuterPackageID
		,o.QuantityPerOuter = s.QuantityPerOuter
		,o.TypicalWeightPerUnit = s.TypicalWeightPerUnit
		,o.LeadTimeDays = s.LeadTimeDays
		,o.IsChillerStock = s.IsChillerStock
		,o.TaxRate = s.TaxRate
		,o.UnitPrice = s.UnitPrice
when not matched then
	insert (
		StockItemName
		,SupplierID
		,UnitPackageID
		,OuterPackageID
		,QuantityPerOuter
		,TypicalWeightPerUnit
		,LeadTimeDays
		,IsChillerStock
		,TaxRate
		,UnitPrice
		,LastEditedBy
		)
	values (
		s.StockItemName
		,s.SupplierID
		,s.UnitPackageID
		,s.OuterPackageID
		,s.QuantityPerOuter
		,s.TypicalWeightPerUnit
		,s.LeadTimeDays
		,s.IsChillerStock
		,s.TaxRate
		,s.UnitPrice
		,(select max(LastEditedBy) from  Warehouse.StockItems )
	)
output $action as [Log],
Inserted.*
;		   
drop table if exists #StockItems

/*
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
*/

select StockItemName as [@Name]
	,SupplierID
	,UnitPackageID as [Package/UnitPackageID]
	,OuterPackageID as [Package/OuterPackageID]
	,QuantityPerOuter as [Package/QuantityPerOuter]
	,TypicalWeightPerUnit as [Package/TypicalWeightPerUnit]
	,LeadTimeDays
	,IsChillerStock
	,TaxRate
	,UnitPrice
from Warehouse.StockItems
for xml path('Item'), root('StockItems'), type

declare @xml xml

select @xml = BulkColumn
from openrowset
(bulk 'D:\HW\homework\hw08\StockItems1.xml',  single_clob) as data 

select @xml as [@xml]

/*
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)
*/

select StockItemID
	,StockItemName
	,CustomFields
	,json_value(CustomFields, '$.CountryOfManufacture') as CountryOfManufacture
	,iif(len( s.FirstTag ) > 1 ,s.FirstTag, null) as FirstTag
	,json_value(CustomFields, '$.Range') as [Range]
from Warehouse.StockItems
cross apply(
	select top 1 
		replace(replace(replace(value,'[','') ,']','')  ,'"','') as FirstTag
	from
		string_split(json_query(CustomFields, '$.Tags') , ',')
) as s

/*
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле

Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.

Должно быть в таком виде:
... where ... = 'Vintage'

Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%' 
*/

select StockItemID
	,StockItemName
	,CustomFields
	,json_query(CustomFields, '$.Tags')  as Tags
from Warehouse.StockItems
cross apply(
	select
		replace(replace(replace(value,'[','') ,']','')  ,'"','') as FirstTag
	from
		string_split(json_query(CustomFields, '$.Tags') , ',')
) as s
where s.FirstTag = 'Vintage'
group by StockItemID, StockItemName, CustomFields
