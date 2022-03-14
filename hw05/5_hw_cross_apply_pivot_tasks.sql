/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/

select format([month], 'dd.MM.yyyy') as InvoiceMonth
	,isnull([Tailspin Toys (Sylvanite, MT)], 0) as 'Sylvanite, MT'
	,isnull([Tailspin Toys (Peeples Valley, AZ)], 0) as 'Peeples Valley, AZ'
	,isnull([Tailspin Toys (Medicine Lodge, KS)], 0) as 'Medicine Lodge, KS'
	,isnull([Tailspin Toys (Gasport, NY)], 0) as 'Gasport, NY'
	,isnull([Tailspin Toys (Jessie, ND)], 0) as 'Jessie, ND'
from
(
	select sc.CustomerName
		,so.OrderID
		,dateadd(day, -day(so.OrderDate) + 1, cast(so.OrderDate as date)) as [month]
	from sales.Orders as so
		join sales.Customers as sc on sc.CustomerID = so.CustomerID
) as s
pivot
(
	count(OrderID) for CustomerName 
		in ([Tailspin Toys (Sylvanite, MT)]
			,[Tailspin Toys (Peeples Valley, AZ)]
			,[Tailspin Toys (Medicine Lodge, KS)]
			,[Tailspin Toys (Gasport, NY)]
			,[Tailspin Toys (Jessie, ND)]
			)
) as pvt 
order by [month]

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/

drop table if exists #a

select DeliveryAddressLine2
into #a
from sales.Customers

select CustomerName, AddressLine
from sales.Customers
cross apply(select DeliveryAddressLine2 as AddressLine from #a) as s 
where CustomerName like '%Tailspin Toys%'

/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

select CountryID
	,CountryName
	,CodeType
	,Code
from
    (
     select ac.CountryID
		,ac.CountryName
		,cast(ac.IsoAlpha3Code as nvarchar) IsoAlpha3Code
		,cast(ac.IsoNumericCode as nvarchar) IsoNumericCode
     from Application.Countries ac
	 ) as s
unpivot(Code for CodeType in(IsoAlpha3Code, IsoNumericCode)) as unpvt;

/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

select sc.CustomerID, sc.CustomerName, o.*
from Sales.Customers as sc
cross apply (
				select top 2 si.StockItemID, si.UnitPrice, so.OrderDate, si.Description
                from Sales.Orders as so
					join Sales.OrderLines as si on so.OrderID = si.OrderID
                where so.CustomerID = sc.CustomerID
                order by si.UnitPrice asc
				) as o
order by sc.CustomerName;
