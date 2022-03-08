/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

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
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

select PersonID, FullName from Application.People
where IsSalesperson = 1 
	and PersonID not in (select distinct SalespersonPersonID from Sales.Invoices where InvoiceDate = '2015-07-04')

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

select StockItemID, StockItemName, UnitPrice
from Warehouse.StockItems
where UnitPrice = (select min(UnitPrice) from Warehouse.StockItems)

select StockItemID, StockItemName, UnitPrice 
from Warehouse.StockItems
where UnitPrice <= all (select UnitPrice from Warehouse.StockItems)

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

--1
with cte as (
	select top 5 TransactionAmount
		,CustomerID
	from Sales.CustomerTransactions
	order by TransactionAmount desc
)

select * 
from Sales.Customers as sc
	join cte as c on sc.CustomerID = c.CustomerID

--2
select * 
from Sales.Customers as sc
join(
	select top 5 TransactionAmount, CustomerID 
	from Sales.CustomerTransactions 
	order by TransactionAmount desc
	) as c on sc.CustomerID = c.CustomerID

--3
select * from Sales.Customers
where CustomerID in (select top 5 CustomerID from Sales.CustomerTransactions order by TransactionAmount desc)

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

with cte as(
	select distinct DeliveryCityID, StockItemID, PackedByPersonID
	from Sales.Customers as sc
		join sales.Invoices as si on sc.CustomerID = si.CustomerID
		join Sales.InvoiceLines as sal on sal.InvoiceID = si.InvoiceID
		join Application.Cities as ac on ac.CityID = sc.DeliveryCityID
		join Application.People as ap on ap.PersonID = si.PackedByPersonID
	where StockItemID in (select top 3 StockItemID from Warehouse.StockItems order by UnitPrice desc)
)

select CityID, CityName from Application.Cities where CityID in (select distinct DeliveryCityID from cte)
union all
select null, FullName from Application.People where PersonID in (select distinct PackedByPersonID from cte)

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC

-- подзапрос в строке (115) получает полное имя продаавца
-- подзапрос в строке (120) вычисляет общую сумму выбранных товаров при этом еще один подзапрос (130) выбирает id заказов для которых выставлен счет и которые собраны
-- подзапрос в строке (129) независимый, он получает id счета и общую сумму заказа где общая сумма больше 27000

select i.InvoiceID
	,i.InvoiceDate
	,(
		select p.FullName
		from Application.People as p
		where p.PersonID = i.SalespersonPersonID
		) as SalesPersonName
	,SalesTotals.TotalSumm as TotalSummByInvoice
	,(
		select sum(ol.PickedQuantity * ol.UnitPrice)
		from Sales.OrderLines ol
		where ol.OrderId = o.OrderId
		) as TotalSummForPickedItems
from Sales.Invoices as i
	join Sales.Orders as o on i.OrderID = o.OrderID 
		and o.PickingCompletedWhen is not null	
		and o.OrderId = i.OrderId
	join (
			select InvoiceId
				,sum(Quantity*UnitPrice) as TotalSumm
			from Sales.InvoiceLines
			group by InvoiceId
			having sum(Quantity*UnitPrice) > 27000
		) as SalesTotals on i.InvoiceID = SalesTotals.InvoiceID
order by TotalSumm desc