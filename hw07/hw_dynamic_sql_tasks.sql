/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "07 - Динамический SQL".

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

Это задание из занятия "Операторы CROSS APPLY, PIVOT, UNPIVOT."
Нужно для него написать динамический PIVOT, отображающий результаты по всем клиентам.
Имя клиента указывать полностью из поля CustomerName.

Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+----------------+----------------------
InvoiceMonth | Aakriti Byrraju    | Abel Spirlea       | Abel Tatarescu | ... (другие клиенты)
-------------+--------------------+--------------------+----------------+----------------------
01.01.2013   |      3             |        1           |      4         | ...
01.02.2013   |      7             |        3           |      4         | ...
-------------+--------------------+--------------------+----------------+----------------------
*/

declare @dml as nvarchar(max)
declare @ColumnName as nvarchar(max)

drop table if exists #person

select format(si.InvoiceDate, 'dd.MM.yyyy') as InvoiceMonth
	,substring(sc.CustomerName, charindex('(',sc.CustomerName) + 1 , len(sc.CustomerName) - charindex('(',sc.CustomerName) - 1 ) as Client
into #person
from Sales.Customers as sc
left join Sales.Invoices as si on si.CustomerID = sc.CustomerID 
	where si.InvoiceDate is not null

select @ColumnName= isnull(@ColumnName + ',','') + quotename(Client)
from (select distinct Client from #person) as Months
order by Client

set @dml = 
  N'  
	;with
	pvtTab as (
		select InvoiceMonth, ' + @ColumnName + ' FROM #person
		pivot(count(Client) for Client in (' + @ColumnName + ')
		) as pvt
	)
	select *
	from pvtTab
	order by cast(substring(InvoiceMonth, 7,4) as int), cast(substring(InvoiceMonth, 4,2) as int), cast(substring(InvoiceMonth, 0,2) as int)
	drop table if exists #person
	'
exec sp_executesql @dml
