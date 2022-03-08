/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/

select StockItemID, StockItemName
from Warehouse.StockItems
where StockItemName like '%urgent%' or StockItemName like 'Animal%'

/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

select distinct ps.SupplierID
	,ps.SupplierName
from Purchasing.Suppliers as ps
	left join Purchasing.PurchaseOrders as pp on ps.SupplierID = pp.SupplierID
where pp.PurchaseOrderID is null

/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/

select sp.OrderID
	,sp.OrderDate
	,datename(m, sp.OrderDate) as [Month]
	,datename(q, sp.OrderDate) as [Quarter]
	,(case
		when cast(month(sp.OrderDate) as int) <= 4 then 1
		when cast(month(sp.OrderDate) as int) > 4 and cast(month(sp.OrderDate) as int) <= 8 then 2
		when cast(month(sp.OrderDate) as int) > 8 then 3
	end) as Third
	,sc.CustomerName as Customer
from Sales.Orders as sp
	left join Sales.OrderLines as ol on sp.OrderId = ol.OrderID
	left join Sales.Customers sc on sp.CustomerID = sc.CustomerID
--пропуск строк
order by sp.OrderDate, [Quarter], Third asc offset 1000 rows fetch first 100 rows only

/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

select ad.DeliveryMethodName
	,pp.ExpectedDeliveryDate
	,ps.SupplierName
	,ap.FullName
from Purchasing.Suppliers as ps
	join Purchasing.PurchaseOrders as pp on ps.SupplierID = pp.SupplierID
	join Application.DeliveryMethods as ad on pp.DeliveryMethodID = ad.DeliveryMethodID
	join Application.People as ap on pp.ContactPersonID = ap.PersonID
where pp.ExpectedDeliveryDate between '2013-01-01' and '2013-01-31'
	and ad.DeliveryMethodName like 'Air Freight' or ad.DeliveryMethodName like 'Refrigerated Air Freight'
	and pp.IsOrderFinalized = 1
		
/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

select top 10 OrderID
	,sc.CustomerName
	,ap.FullName
from sales.Orders as o
	join Application.People as ap on o.SalespersonPersonID = ap.PersonID
	join Sales.Customers as sc on o.CustomerID = sc.CustomerID
order by o.OrderDate desc

/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

select sc.CustomerID
	,sc.CustomerName
	,sc.PhoneNumber
from Sales.Customers sc
	join Sales.Orders as so on sc.CustomerID = so.CustomerID
	join Sales.OrderLines as sol on so.OrderID = sol.OrderID
	join Warehouse.StockItems as ws on sol.StockItemID = ws.StockItemID
where ws.StockItemName like 'Chocolate frogs 250g'

/*
7. Посчитать среднюю цену товара, общую сумму продажи по месяцам
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select month(si.InvoiceDate) as [month]
	,year(si.InvoiceDate) as [year]
	,sl.UnitPrice * sl.Quantity as TotalPrice
	,sum(sl.UnitPrice * sl.Quantity)/sum(sl.Quantity) as avgPrice
from Sales.Invoices as si
	join Sales.InvoiceLines as sl on si.InvoiceID = sl.InvoiceID
	join Warehouse.StockItems as ws on sl.StockItemID = ws.StockItemID
group by month(si.InvoiceDate), year(si.InvoiceDate), sl.UnitPrice, sl.Quantity, ws.StockItemName
order by month(si.InvoiceDate), year(si.InvoiceDate)

/*
8. Отобразить все месяцы, где общая сумма продаж превысила 10 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select 
	month(si.InvoiceDate) as [month]
	,year(si.InvoiceDate) as [year]
	,sl.UnitPrice * sl.Quantity as TotalPrice
from Sales.Invoices as si
	join Sales.InvoiceLines as sl on si.InvoiceID = sl.InvoiceID
	join Warehouse.StockItems as ws on sl.StockItemID = ws.StockItemID
group by month(si.InvoiceDate), year(si.InvoiceDate), sl.UnitPrice, sl.Quantity
having (sl.UnitPrice * sl.Quantity) > 10000
order by month(si.InvoiceDate), year(si.InvoiceDate)

/*
9. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select 
	month(si.InvoiceDate) as [month]
	,year(si.InvoiceDate) as [year]
	,ws.StockItemName
	,sl.Quantity as TotalQuantity
	,sum(sl.UnitPrice * sl.Quantity) as Sum
	,sl.UnitPrice
	,min(InvoiceDate) as firstDate
from Sales.Invoices as si
	join Sales.InvoiceLines as sl on si.InvoiceID = sl.InvoiceID
	join Warehouse.StockItems as ws on sl.StockItemID = ws.StockItemID
group by month(si.InvoiceDate), year(si.InvoiceDate), sl.UnitPrice, sl.Quantity, ws.StockItemName
having sl.Quantity < 50
order by month(si.InvoiceDate), year(si.InvoiceDate)

-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 8-9 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/
