/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "12 - Хранимые процедуры, функции, триггеры, курсоры".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

USE WideWorldImporters

/*
Во всех заданиях написать хранимую процедуру / функцию и продемонстрировать ее использование.
*/

/*
1) Написать функцию возвращающую Клиента с наибольшей суммой покупки.
*/

create or alter function IDCustomerMaxPurchase()
returns int
as
begin
	declare @ID int;
	with cte as(
		select sil.InvoiceID
				,sum(sil.Quantity * isnull(sil.UnitPrice, si.UnitPrice)) as Amount
		from Sales.InvoiceLines as sil
			join Warehouse.StockItems as si on sil.StockItemID = si.StockItemID
		group by sil.InvoiceID
	)
		select top 1 @ID = sc.CustomerID
		from Sales.Invoices as si
			join cte on si.InvoiceID = cte.InvoiceID
			join Sales.Customers as sc on si.CustomerID = sc.CustomerID
		order by cte.Amount desc
	return @ID
end

print dbo.IDCustomerMaxPurchase()

/*
2) Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
Использовать таблицы :
Sales.Customers
Sales.Invoices
Sales.InvoiceLines
*/

create or alter procedure CustomerPurchaseAmount @ID int
as
begin
set nocount on;
	select @ID as ID, 
		(
			select sum(sil.Quantity * sil.UnitPrice)
			from Sales.InvoiceLines as sil
				join Sales.Invoices as si on sil.InvoiceID = si.InvoiceID
			where si.CustomerID = @ID
			) as Amount
end

exec dbo.CustomerPurchaseAmount 834

/*
3) Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.
*/
set statistics time, io on

--func выводит покупателей и их заказы для заданной даты

create or alter function GetCustomers(@date date)
returns table
as
return
(
	select sc.CustomerID
		,sc.CustomerName
		,si.OrderID
		,si.InvoiceDate
	from sales.Customers sc
		join sales.Invoices as si on si.CustomerID = sc.CustomerID
	where si.InvoiceDate = @date
);

select * from dbo.GetCustomers('2014-01-03')

 --SQL Server Execution Times:
 --  CPU time = 16 ms,  elapsed time = 23 ms.

--proc выводит покупателей и их заказы для заданной даты

create or alter procedure GetCustomersTab(@date date)
as
begin
select sc.CustomerID
	,sc.CustomerName
	,si.OrderID
	,si.InvoiceDate
from sales.Customers sc
	join sales.Invoices as si on si.CustomerID = sc.CustomerID
where si.InvoiceDate = @date
end

exec dbo.GetCustomersTab '2014-01-03'

-- SQL Server Execution Times:
--   CPU time = 15 ms,  elapsed time = 18 ms.

-- SQL Server Execution Times:
--   CPU time = 31 ms,  elapsed time = 32 ms.

/*
4) Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла. 
*/

--возвращает все заказы для указанного клиента
create or alter function GetInvoicesForCustomer(@ID int)
returns table
as
return
(
	select sc.CustomerName
		,si.OrderID
		,si.InvoiceDate
	from sales.Customers sc
		join sales.Invoices as si on si.CustomerID = sc.CustomerID
	where si.CustomerID = @ID
);


--вывод для каждой строки с помощью cross apply
select sc.CustomerID
	,f.CustomerName
	,f.OrderID
	,f.InvoiceDate
from sales.Customers as sc
	cross apply dbo.GetInvoicesForCustomer(sc.CustomerID) as f
order by sc.CustomerID

/*
5) Опционально. Во всех процедурах укажите какой уровень изоляции транзакций вы бы использовали и почему. 
*/
