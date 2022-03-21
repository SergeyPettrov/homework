/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

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
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/

--select * from Sales.Customers

drop table if exists #s

select top(5) (cast(CustomerID as int) + 5) as CustomerID,(CustomerName + '1') as CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy
into #s
from sales.Customers order by CustomerID desc

insert into sales.Customers (CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy)
select CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy
from #s

/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/

--select * from Sales.Customers

delete from Sales.Customers
where CustomerID = 1066

/*
3. Изменить одну запись, из добавленных через UPDATE
*/

--select * from Sales.Customers

update Sales.Customers
set CustomerName = (CustomerName + 'change')
where CustomerID = 1065

/*
4. Написать MERGE, который вставит вставит запись в клиенты, если ее там нет, и изменит если она уже есть
*/

--select * from Sales.Customers

merge into Sales.Customers as t
using (
	values (1069, 'Nguyen Banh_upd', 1042, 3, NULL, 3242, NULL, 3, 11696, 11696, null, '2015-01-22', 0, 0, 0, 7, '(239) 555-0100', '(239) 555-0101', null, null, 'http://www.microsoft.com/', 'Unit 7', '1885 William Boulevard', 90744, null, 'PO Box 8476', 'Bhanuville', 90744, 1)
) as s (CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy)
	on s.CustomerID = t.CustomerID
when not matched then
	insert (CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy)
	values (s.CustomerID, s.CustomerName, s.BillToCustomerID, s.CustomerCategoryID, s.BuyingGroupID, s.PrimaryContactPersonID, s.AlternateContactPersonID, s.DeliveryMethodID, s.DeliveryCityID, s.PostalCityID, s.CreditLimit, s.AccountOpenedDate, s.StandardDiscountPercentage, s.IsStatementSent, s.IsOnCreditHold, s.PaymentDays, s.PhoneNumber, s.FaxNumber, s.DeliveryRun, s.RunPosition, s.WebsiteURL, s.DeliveryAddressLine1, s.DeliveryAddressLine2, s.DeliveryPostalCode, s.DeliveryLocation, s.PostalAddressLine1, s.PostalAddressLine2, s.PostalPostalCode, s.LastEditedBy)
when matched then
	update
	set CustomerName = s.CustomerName
;

/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/

-- bcp out ----------------------------------
exec sp_configure 'xp_cmdshell', 1
reconfigure

exec master..xp_cmdshell 'bcp "select CustomerID, CustomerName FROM WideWorldImporters.Sales.Customers" queryout D:\HW\homework\hw10\Out.txt -T -w -t"@eu&$1&"'

-- bulk insert -----------------------------
create table Sales.Import(
	CustomerID int,
	CustomerName varchar(50)
);

bulk insert Sales.Import
from "D:\HW\homework\hw10\Out.txt"
with (
	batchsize = 1000,
	datafiletype = 'widechar',
	fieldterminator = '@eu&$1&',
	rowterminator ='\n',
	keepnulls,
	tablock
);
