--polaczenie wszystkiego

IF OBJECT_ID('tempdb..#final') is not null drop table #final
SELECT *
into #final
FROM
(
select * from #ocena_output
UNION ALL
select * from #otwarte_Output
UNION ALL
select * from #rozwiazane_output
UNION ALL
select * from #pending_output
UNION ALL
select * from #life_tran_output
UNION ALL
select Osoba collate database_default  , Aspekt , WolumenZarejestrowanychKomponentow, Kategoria from #rejestr_komp_output
UNION ALL
select Osoba, Status collate database_default, WolumenPaymentRequestow, Kategoria from #payment_request_output
UNION ALL
select * from #rejestracje_output
UNION ALL
select * from #opiniemedyczne_output
UNION ALL
select * from #decyzje_output
UNION ALL
select * from #oczekujace_output
UNION ALL
select * from #TIA_output

) FINAL

select * from #FINAL

--dynamiczny pivot
--wyciagam nazwy kolumn do jednej zmiennej. Przedzielone przecinkiem
declare @cols AS nvarchar(max) = 
stuff((select distinct ',' + QUOTENAME(F.Pracownik) from #final f for xml path(''), type).value('.','nvarchar(max)'), 1,1,'')


print @cols

declare @query as nvarchar(max) =
'select aspekt, '+ @cols + ' from (select * from #final) a pivot ( max(Wolumen) for Pracownik in (' + @cols + ')) p '
execute(@query)