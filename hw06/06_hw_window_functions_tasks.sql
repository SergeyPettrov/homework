/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

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
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

set statistics time, io on
--CPU time = 39422 ms,  elapsed time = 41185 ms.

select si.InvoiceID 
    ,sc.CustomerName 
    ,si.InvoiceDate 
	,(select sum(sil.Quantity * sil.UnitPrice) from Sales.InvoiceLines as sil where sil.InvoiceID = si.InvoiceID) as OrderSum
	,(
		select sum(sil.Quantity * sil.UnitPrice)
		from Sales.InvoiceLines as sil 
			join Sales.Invoices as i on sil.InvoiceID = i.InvoiceID 
		where i.InvoiceDate <= eomonth(si.InvoiceDate) 
			and i.InvoiceDate between '2015-01-01' and '2015-12-31'
		) as TotalSum
from Sales.Invoices as si
    join Sales.Customers sc on si.CustomerID = sc.CustomerID
    join Sales.InvoiceLines il on si.InvoiceID = il.InvoiceID
where si.InvoiceDate between '2015-01-01' and '2015-12-31'
order by si.InvoiceDate, si.CUstomerID

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

set statistics time, io on
--CPU time = 328 ms,  elapsed time = 1675 ms.

select si.InvoiceID
	,sc.CustomerName
	,si.InvoiceDate
	,sum(sil.Quantity * sil.UnitPrice) over (partition by si.InvoiceID) as OrderSum
	,sum(sil.Quantity * sil.UnitPrice) over (order by datepart(year, si.InvoiceDate), datepart(month, si.InvoiceDate)) as TotalSum
from Sales.Invoices si
	join Sales.Customers sc on sc.CustomerID = si.CustomerID
	join Sales.InvoiceLines sil on sil.InvoiceID = si.InvoiceID
where si.InvoiceDate between '2015-01-01' and '2015-12-31'
order by si.InvoiceDate, si.CustomerID

/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

with cteMonthSales
as (
    select ws.StockItemName
		,sum(sil.Quantity) as TotalQuantity
        ,month(si.InvoiceDate) as MonthNumber
    from Sales.InvoiceLines sil
        join Sales.Invoices as si on sil.InvoiceID = si.InvoiceID 
        join Warehouse.StockItems ws on sil.StockItemID = ws.StockItemID
	where year(si.InvoiceDate) = 2016
    group by ws.StockItemName, month(si.InvoiceDate)
),
cteSalesNumbered
as (
    select cms.StockItemName
        ,cms.TotalQuantity
        ,cms.MonthNumber
        ,row_number() over(partition by cms.MonthNumber order by cms.TotalQuantity desc) as num
    from cteMonthSales as cms
)
select csn.StockItemName, csn.TotalQuantity
from cteSalesNumbered csn
where csn.num <= 2
order by csn.MonthNumber, csn.TotalQuantity desc

/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

select si.StockItemID
    ,si.StockItemName
    ,si.Brand
    ,row_number() over(partition by left(si.StockItemName, 1) order by si.StockItemName)as NumberFirstChar
    ,count(*) over() as TotalCount
    ,count(*) over(partition by left(si.StockItemName, 1)) as TotalCountFirstChar
    ,lead(si.StockItemID) over(order by si.StockItemName) as NextId
    ,lag(si.StockItemID) over(order by si.StockItemName) as PrevId
    ,lag(si.StockItemName, 2, 'No items') over(order by si.StockItemName) Prev2RowName
    ,ntile(30) over(order by si.TypicalWeightPerUnit) GroupWeight
from Warehouse.StockItems si
order by si.StockItemName

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

select ap.PersonID
       ,ap.FullName
       ,sc.CustomerID
       ,sc.CustomerName
       ,s.TransactionDate
       ,s.TransactionAmount
from
(
    select sct.CustomerID
           ,si.SalespersonPersonID
           ,sct.TransactionDate
           ,sct.TransactionAmount
           ,row_number() over(partition by SalespersonPersonID order by TransactionDate desc) as num
    from Sales.CustomerTransactions as sct
         join Sales.Invoices si on sct.InvoiceID = si.InvoiceID
) as s
	join Application.People ap on s.SalespersonPersonID = ap.PersonID
	join Sales.Customers sc on s.CustomerID = sc.CustomerID
where s.num = 1

/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

select sc.CustomerID
	,sc.CustomerName
	,s.StockItemID
	,s.StockItemName
	,s.UnitPrice
	,s.InvoiceDate
from
(
    select i.CustomerID
		,sil.StockItemID
		,ws.StockItemName
		,ws.UnitPrice
		,i.InvoiceDate
		,row_number() over(partition by i.CustomerID order by ws.UnitPrice desc) as num
    from Sales.InvoiceLines sil
         join Sales.Invoices i on sil.InvoiceID = i.InvoiceID
         join Warehouse.StockItems ws on sil.StockItemID = ws.StockItemID
) as s
	join Sales.Customers sc on s.CustomerID = sc.CustomerID
where s.Num <= 2

--Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность.