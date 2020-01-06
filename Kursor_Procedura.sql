alter PROCEDURE reports.CL_Audyt_Wewnetrzny_proc    
as    
BEGIN TRY           
 declare @i int          
 ---===================================================================================================---                    
 --- Zapis w logach ---                    
 ---===================================================================================================---                    
                    
 insert into data.Procedures_LOG_History (ProcedureName, startTime) values (object_name(@@procid), getdate())                    
 set @i = @@identity                    
  ---===================================================================================================---                    
 --- KOD ---                    
 ---===================================================================================================---     
 --ustawiam daty dla audytowanego miesiaca    
 declare @Start date = '2019-09-01'--( select FirstDayOfMonth from dict.DimDate where DataID = convert(date,DATEADD (month,-1,getdate()),112)) --   
 declare @End date = '2019-09-30' --( select LastDayOfMonth from dict.DimDate where DataID = convert(date,DATEADD (month,-1,getdate()),112))  --  
 
 --testowo  
 if 1=0   
 begin  
	 delete reports.CL_Audyt_Wewnetrzny_Uwagi where DataDecyzjiRRRRMC like '201909'  
	 delete reports.CL_Audyt_Wewnetrzny where DataDecyzjiRRRRMC like '201909'  
 end  
    
 --deklaruje sobie wszystkie potrzebne zmienne    
	 declare  @licznik int = 0    
	 declare @Dorzucono int = 0    
	 declare @FastTrack int = 0    
	 declare @Odmowa int = 0    
	 declare @Akceptacje int = 0    
	 declare @AkceptacjeNaDrugaReke int = 0    
	 declare @OpinieMedyczne int = 0    
	 declare @RowNumber int = 0    
	 declare @LosoweUzupelnienie int = 0
	 declare @query nvarchar(max) = ''
	 declare @roznica int = 0

 
   
 --deklaruje kursor, w ktorym znajduja sie wszyscy pracownicy CL   
 --------starttest-------------------------------------------------------------
  
 Declare @Pracownik nvarchar(100)    
 DECLARE Pracownicy CURSOR FOR --select '1ND52EB'    
    select CorporateKey from letters.Users    
    where CorporateKey in ('ND52EB','WR52HH','CF58EN','OK19YD','DJ13UF','RI56SR','BN25LP','DO70RY','NO99VL','IV91BK','QS89AH','BK53QP','AM62KB','BU83GA','PF35ZB','BI98TW','FN10ED', 'CA63CU')      
	-- print 'test1'
 --otwieram transakcje, która  nie pozwoli na wpisanie wiecej niz 5 spraw dla danego okresu (tylko tyle spraw chcemy miec do audytu)
 BEGIN TRANSACTION   
 OPEN Pracownicy    
 FETCH NEXT FROM Pracownicy INTO @Pracownik    
 WHILE @@FETCH_STATUS = 0    
    
 BEGIN --poczatek kursora    
	 --zeruje wszystkie liczniczki    
	 set @licznik = 0     
	 set @FastTrack = 0    
	 set @Odmowa = 0    
	 set @Akceptacje = 0    
	 set @AkceptacjeNaDrugaReke = 0    
	 set @OpinieMedyczne = 0   
	 set @query = ''
	 set @roznica = 0
	 set @LosoweUzupelnienie = 0
	 set @RowNumber = 0
  
	 --TESTOWO  -> WAZNE ZEBY TESTOWAC NA OKRESIE KTORY NIE BYL BRANY DO AUDYTOWANIA tj. nie pozniej niz 201909 -> dobrze jest zachowac archiwalne sprawy do kontroli
	-- DECLARE @PRACOWNIK NVARCHAR(10)= 'CA63CU'  
	 --declare @Start date = '2019-06-01'--( select FirstDayOfMonth from dict.DimDate where DataID = convert(date,DATEADD (month,-1,getdate()),112)) --   
	 --declare @End date = '2019-06-30' --( select LastDayOfMonth from dict.DimDate where DataID = convert(date,DATEADD (month,-1,getdate()),112))   
	 --declare  @licznik int = 0    
	 --declare @Dorzucono int = 0    
	 --declare @FastTrack int = 0    
	 --declare @Odmowa int = 0    
	 --declare @Akceptacje int = 0    
	 --declare @AkceptacjeNaDrugaReke int = 0    
	 --declare @OpinieMedyczne int = 0    
	 --declare @RowNumber int = 0    
	 --declare @LosoweUzupelnienie int = 0
	 --declare @query nvarchar(max) = ''
	 --declare @roznica int = 0

	 --FastTracki- niskie wyp³aty -> przygotowanie tabelki  
	 if OBJECT_ID('tempdb..#Fast_Track') is not null drop table #Fast_Track  
	 SELECT --top 2                
	  DataDecyzjiRRRRMC             
	  , @Pracownik Pracownik                
	  , LiniaBiznesowa                 
	  , NrClaim                     
	  , NrKontraktu                   
	  , TypKontraktu                   
	  , TypUmowy                    
	  , TypRoszczenia                  
	  , StatusClaim                    
	  , StatusKomponentu                 
	  , StatusPaymentRequesta               
	  , KwotaPaymentRequesta                
	  , UzytkownikRejestrujacyKomponent           
	  , UzytkownikDecyzja                 
	  , UzytkownikRejestrujacyWyplate            
	  , UzytkownikAkceptujacyWyplate         
	  , 'Fast Track' Kategoria           
	 into #Fast_Track  
	 FROM reports.CL_Payments    
	 where uzytkownikrejestrujacywyplate = @Pracownik    
	  and UzytkownikRejestrujacyWyplate = UzytkownikAkceptujacyWyplate    
	  and DataDecyzji between @Start and @End    
	  and KwotaWyplaty <= 10000    
	  and StatusPaymentRequesta = 'PAID'    
	  and StatusKomponentu = 'PAIDOUT'  
  
	--Insert z tabelki #FastTrack  
	 INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC ,Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu , TypKontraktU, TypUmowy   
	 , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent  
	 , UzytkownikDecyzja, UzytkownikRejestrujacyWyplate, UzytkownikAkceptujacyWyplate, Kategoria  )   
	 Select Top 2 * from #Fast_Track order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID()     
  
	 set @RowNumber = @@ROWCOUNT    
	 set @licznik = @RowNumber + @licznik    
	 set @FastTrack = @RowNumber    
	 print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' fast trackow'    
  
	 --Tabelka z Odmowami  
	 if OBJECT_ID('tempdb..#Odmowa') is not null drop table #Odmowa  
		SELECT --TOP 2     
		DataDecyzjiRRRRMC       DataDecyzjiRRRRMC    
	  , @Pracownik       collate SQL_Latin1_General_CP1_CI_AS  Pracownik   
	  , LiniaBiznesowa        collate Polish_CI_AS  LiniaBiznesowa      
	  , NrClaim          collate Polish_CI_AS  NrClaim        
	  , NrKontraktu         collate Polish_CI_AS  NrKontraktu       
	  , TypKontraktu        collate Polish_CI_AS  TypKontraktu      
	  , TypUmowy         collate Polish_CI_AS  TypUmowy       
	  , TypRoszczenia        collate Polish_CI_AS  TypRoszczenia      
	  , StatusClaim         collate Polish_CI_AS  StatusClaim       
	  , StatusKomponentu       collate Polish_CI_AS  StatusKomponentu     
	  ,CAST ( ''  AS NVARCHAR(100))   collate Polish_CI_AS StatusPaymentRequesta    
	  ,CAST ( null  AS numeric)    KwotaPaymentRequesta    
	  , UzytkownikRejestrujacyKomponent collate Polish_CI_AS UzytkownikRejestrujacyKomponent   
	  , UzytkownikDecyzja       collate Polish_CI_AS UzytkownikDecyzja        
	  , CAST ( ''  AS NVARCHAR(100))  collate Polish_CI_AS UzytkownikRejestrujacyWyplate    
	  , CAST ( ''  AS NVARCHAR(100))  collate Polish_CI_AS UzytkownikAkceptujacyWyplate    
	  , 'Odmowa'        collate SQL_Latin1_General_CP1_CI_AS Kategoria  
	 into #Odmowa  
	 FROM reports.CL_DASHBOARD_FULL_new_tbl    
	 where 1=1    
	  and UzytkownikRejestrujacyKomponent = @Pracownik    
	  and StatusKomponentu = 'REFUSED'    
	  and DataDecyzji between @Start and @End    
  
	--insert kategoria = 'ODMOWA'
	 if @Pracownik not in ('PF35ZB', 'CF58EN')    
	  begin    
	   INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC ,Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu , TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu   
	   , StatusPaymentRequesta  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )  
	   Select TOP 2 * from #Odmowa   
	   order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID()    
	  end    
	 else --teraz opcja dla Pracowników, którzy przygotowywuj¹ opinie medyczne    
	  begin    
	   INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC ,Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu , TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta    
	   , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
	   Select TOP 1 * from #Odmowa   
	   order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID()       
	  end    
	 set @RowNumber = @@ROWCOUNT    
	 set @licznik = @RowNumber + @licznik    
	 set @Odmowa = @RowNumber    
	 print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' odmow'    
  
	 --Akceptacje na drug¹ rêkê- tabelka  
	 if OBJECT_ID('tempdb..#Akceptacja_Druga_Reka') is not null drop table #Akceptacja_Druga_Reka  
	 SELECT     
	  DataDecyzjiRRRRMC    
	  , @Pracownik  Pracownik  
	  , LiniaBiznesowa    
	  , NrClaim    
	  , NrKontraktu    
	  , TypKontraktu    
	  , TypUmowy    
	  , TypRoszczenia    
	  , StatusClaim    
	  , StatusKomponentu    
	  , StatusPaymentRequesta    
	  , KwotaPaymentRequesta    
	  , UzytkownikRejestrujacyKomponent    
	  , UzytkownikDecyzja    
	  , UzytkownikRejestrujacyWyplate    
	  , UzytkownikAkceptujacyWyplate    
	  , N'Akceptacja na drug¹ rêkê' Kategoria    
	 into #Akceptacja_Druga_Reka  
	 FROM reports.CL_Payments    
	 where uzytkownikrejestrujacywyplate = @Pracownik    
	  and UzytkownikRejestrujacyWyplate <> UzytkownikAkceptujacyWyplate    
	  and DataDecyzji between @Start and @End    
	  and KwotaWyplaty > 10000    
	  and StatusPaymentRequesta = 'PAID'    
	  and StatusKomponentu = 'PAIDOUT'    
  
  
	 if @Pracownik not in ('PF35ZB', 'CF58EN')   
	 begin   
	  INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC ,Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu , TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta    
	  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
	  Select top 1 *   
	  from #Akceptacja_Druga_Reka  
	  order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID()    
	 end  
  
	 set @RowNumber = @@ROWCOUNT    
	 set @AkceptacjeNaDrugaReke = @RowNumber    
	 set @licznik = @RowNumber + @licznik    
	 print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' akceptacji na druga reke'    
    
	 --GDY NIE NAZBIERA SIÊ 5 SPRAW Z POWY¯EJ TO PATRZE NA AKCEPTCAJE   
	 --Tworzê tabelkê z akceptacjami   
	 IF OBJECT_ID('TEMPDB..#Akceptacja') IS NOT NULL drop table #Akceptacja   
	 SELECT --top 5     
	  DataDecyzjiRRRRMC    
	  , @Pracownik Pracownik    
	  , LiniaBiznesowa    
	  , NrClaim    
	  , NrKontraktu    
	  , TypKontraktu    
	  , TypUmowy    
	  , TypRoszczenia    
	  , StatusClaim    
	  , StatusKomponentu    
	  , StatusPaymentRequesta    
	  , KwotaPaymentRequesta    
	  , UzytkownikRejestrujacyKomponent    
	  , UzytkownikDecyzja    
	  , UzytkownikRejestrujacyWyplate    
	  , UzytkownikAkceptujacyWyplate     
	  , 'Akceptacja Payment Requesta' Kategoria    
	 into #Akceptacja    
	 FROM reports.CL_Payments    
	 where 1=1    
	  --and uzytkownikrejestrujacywyplate = 'FN10ED'    
	  and UzytkownikRejestrujacyWyplate <> UzytkownikAkceptujacyWyplate    
	  and UzytkownikAkceptujacyWyplate =  @Pracownik    
	  and DataDecyzji between @Start and @End    
	  and KwotaWyplaty > 10000    
	  and StatusPaymentRequesta = 'PAID'    
	  and StatusKomponentu = 'PAIDOUT' 

	  --uzupe³niam akceptacjami
	 if @Pracownik not in ('PF35ZB', 'CF58EN') 
	 begin   
		set @roznica = 5 - @licznik    
		if @roznica > 0     
		begin    
		  set @query = 'INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC , Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu   
		  , TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent  
		  , UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
    
		   select top ' + cast(@roznica as varchar(5)) + ' * from #Akceptacja order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID() '    
		  --print @query    
		  exec (@query)     
		  set @RowNumber = @@ROWCOUNT    
		  set @Akceptacje = @RowNumber 
		  set @licznik = @licznik + @RowNumber   
		  print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' akceptacji'   
		end      
	 end   
    
      
	 --Opinie Medyczne ( 2 opinie)    
	 IF OBJECT_ID('TEMPDB..#Opinia_medyczna') IS NOT NULL drop table #Opinia_medyczna  
	 select --top 2    
	  cast(convert(nvarchar(6),medical_opinion_date,112) as int) RRRRMM    
	  , @Pracownik Pracownik   
	  , dashboard.LiniaBiznesowa    
	  , dashboard.NrClaim    
	  , dashboard.NrKontraktu    
	  , dashboard.TypKontraktu    
	  , dashboard.TypUmowy    
	  , dashboard.TypRoszczenia    
	  , dashboard.StatusClaim    
	  , dashboard.StatusKomponentu    
	  , cast('' as nvarchar(100)) collate SQL_Latin1_General_CP1_CI_AS as StatusPaymenta    
	  , cast(null as numeric) as KwotaPay    
	  , dashboard.UzytkownikRejestrujacyKomponent    
	  , opinion_user_code UzytkownikDecyzja    
	  , null UzytkownikRejestrujacy    
	  , null Akceptujacy    
	  , 'Opinia medyczna' Kategoria    
	 into #Opinia_medyczna  
	 from COP_CLAIM_DB.claim.customer_contract cucont with (nolock)    
	 join COP_CLAIM_DB.claim.component comp with (nolock)    
	  on comp.customer_contract_id = cucont.customer_contract_id    
	 join COP_CLAIM_DB.claim.medical_decision med with (nolock)    
	  on comp.component_id = med.component_id    
	 join COP_CLAIM_DB.claim.claim cl with (nolock)    
	  on cl.claim_id = cucont.claim_id    
	 join DAB.reports.CL_DASHBOARD_FULL_new_tbl dashboard    
	  on IDKomponent = comp.component_id    
	 where 1=1    
	  and med.medical_opinion_date between @Start and @End    
	  and comp.registration_user_code <> med.opinion_user_code    
	  and med.opinion_user_code = @Pracownik    
	  --and med.medical_decision <> 'false' --ta decyzja oznacza czy opinia jest za wyplata ('tak') czy za odmowa ('nie')    
  
	 if @Pracownik  in ('PF35ZB', 'CF58EN')    
	 INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC ,Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu   
	 , TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta  , KwotaPaymentRequesta  
	 , UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
   
	 Select top 2 * from #Opinia_medyczna  
	 order by ROW_NUMBER() over (partition by TypRoszczenia order by (select 1 ) ) , NEWID()    
    
	 set @RowNumber = @@ROWCOUNT    
	 set @OpinieMedyczne = @RowNumber    
	 set @licznik = @RowNumber + @licznik    
	 print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' opinii medycznych'    
  
	 --LOSOWE UZUPE£NIANIE BRAKUJ¥CYCH SPRAW -> PRZYGOTOWANIE TABEL
	 set @roznica = 5 - @licznik    
	 if @roznica>0 
	 begin  
		IF OBJECT_ID('TEMPDB..#Agregat_WithoutMedical') IS NOT NULL drop table #Agregat_WithoutMedical  
		SELECT *   
		into #Agregat_WithoutMedical  
		FROM  
		(  
		 SELECT * FROM #Akceptacja UNION ALL  
		 SELECT * FROM #Akceptacja_Druga_Reka UNION ALL  
		 SELECT * FROM #Fast_Track UNION ALL  
		 SELECT * FROM #Odmowa   
		) AGR  

		IF OBJECT_ID('TEMPDB..#Agregat_WithMedical') IS NOT NULL drop table #Agregat_WithMedical  
		SELECT *   
		into #Agregat_WithMedical  
		FROM  
		(  
		SELECT DataDecyzjiRRRRMC, Pracownik, LiniaBiznesowa, NrClaim, NrKontraktu, TypKontraktu, TypUmowy, TypRoszczenia, StatusClaim, StatusKomponentu  
		 , StatusPaymentRequesta, KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate, UzytkownikAkceptujacyWyplate, Kategoria  
		FROM #Agregat_WithoutMedical   
		UNION ALL  
		SELECT RRRRMM, Pracownik, LiniaBiznesowa, NrClaim, NrKontraktu, TypKontraktu, TypUmowy, TypRoszczenia, StatusClaim, StatusKomponentu  
		 , StatusPaymenta collate Polish_CI_AS, KwotaPay, UzytkownikRejestrujacyKomponent, UzytkownikDecyzja, cast(UzytkownikRejestrujacy as nvarchar(max)) , cast(Akceptujacy as nvarchar(max)), Kategoria   
		FROM #Opinia_medyczna   
		) AGR     
		--'DOPYCHAMY LOSOWO' BRAKUJ¥CE SPRAWY  

		if @Pracownik  in ('PF35ZB', 'CF58EN')    
		begin      
			set @query = 'INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC , Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu   
			, TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent  
			, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
    
			select top ' + cast(@roznica as varchar(5)) + ' * from #Agregat_WithMedical order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID() '    
			--print @query    
			exec (@query)     
			set @RowNumber = @@ROWCOUNT    
			set @Akceptacje = @RowNumber    
			print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + ' akceptacji'    
		     
		end  
		else
		begin
			set @query = 'INSERT INTO reports.CL_Audyt_Wewnetrzny (DataDecyzjiRRRRMC , Pracownik, LiniaBiznesowa , NrClaim , NrKontraktu   
			, TypKontraktU, TypUmowy , TypRoszczenia, StatusClaim , StatusKomponentu , StatusPaymentRequesta  , KwotaPaymentRequesta, UzytkownikRejestrujacyKomponent  
			, UzytkownikDecyzja, UzytkownikRejestrujacyWyplate,UzytkownikAkceptujacyWyplate,  Kategoria  )    
    
			select top ' + cast(@roznica as varchar(5)) + ' * from #Agregat_WithoutMedical order by row_number() over (partition by TypRoszczenia order by (Select 1)), NewID() ; 
			set'    
			--print @query    
			   
			set @RowNumber = @@ROWCOUNT    
			set @LosoweUzupelnienie = @RowNumber
			    
			print 'Dla pracownika ' +@Pracownik + ' ' + cast(@RowNumber as varchar(2)) + N' losowych uzupe³nieñ'
		end  
	  end
   
  
    
	 --PODSUMOWANIE I UWAGI--    
    
	 INSERT INTO reports.CL_Audyt_Wewnetrzny_Uwagi ( DataDecyzjiRRRRMC , Pracownik, FastTrack , Odmowa , AkceptacjeNaDrugaReke, Akceptacje, OpinieMedyczne, LosoweUzupelnienie )    
	 Select     
	  cast(convert(varchar(6),@Start,112) as int) as RRRRMC    
	  , @Pracownik    
	  , @FastTrack    
	  , @Odmowa    
	  , @AkceptacjeNaDrugaReke    
	  , @Akceptacje    
	  , @OpinieMedyczne 
	  , @LosoweUzupelnienie   
	 FETCH NEXT FROM Pracownicy INTO @Pracownik   
  END    --konier kursora
  CLOSE Pracownicy    
  DEALLOCATE Pracownicy    
  print N'Kursor siê zakoñczy³'  
 -- ROLLBACK TRANSACTION

--starttest---------------------------------------------------------------------------

  --gdy jest wiecej niz 5 sztuk w ramach jednego miesiaca i pracownika to rollback -> dane sie nie zapisza!   
  IF  ( SELECT top 1 COUNT(*) FROM reports.CL_Audyt_Wewnetrzny group by Pracownik, DataDecyzjiRRRRMC order by 1 desc) > 5  
  begin  
	ROLLBACK TRANSACTION
	select  N'Rollback- s¹ ju¿ dane na ten miesi¹c'  
  end  
  ELSE   
  begin  
	COMMIT TRANSACTION   
	select 'Dodano nowe dane- COMMIT'  
  end   
  
  if 1=0    
  select * from letters.Users    
  where corporatekey in (select Pracownik from reports.CL_Audyt_Wewnetrzny_Uwagi where SumaSpraw <5 and DataDecyzjiRRRRMC = '201907' )    
    
 ---===================================================================================================---                    
 --- Zapis w logach ---                    
 ---===================================================================================================---        
  update dab.data.Procedures_LOG_History set middleTime = getdate() where id = @i                    
 ---===================================================================================================---                    
 --- Zapis w logach ---                    
 ---===================================================================================================---         
  update dab.data.Procedures_LOG_History set endTime = getdate() where id = @i                    
END TRY             
BEGIN CATCH                    
                    
 update [DAB].[data].[Procedures_LOG_History] set Data = getdate() where id = @i                    
 update [DAB].[data].[Procedures_LOG_History] set ErrorNumber = ERROR_NUMBER() where id = @i                    
 update [DAB].[data].[Procedures_LOG_History] set ErrorSeverity = ERROR_SEVERITY() where id = @i                    
 update [DAB].[data].[Procedures_LOG_History] set ErrorState = ERROR_STATE() where id = @i                    
 update [DAB].[data].[Procedures_LOG_History] set ErrorProcedure = ERROR_PROCEDURE() where id = @i                    
 update [DAB].[data].[Procedures_LOG_History] set ErrorLine = ERROR_LINE()+8 where id = @i         
 update [DAB].[data].[Procedures_LOG_History] set ErrorMessage = ERROR_MESSAGE() where id = @i                    
                    
END CATCH     
    
--Historyczny kod:  
--------------------------------------------------  
  
 --Generowanie Tabelki  
  --tworze tabelke reports.CL_Audyt_Wewnetrzny    
  --IF OBJECT_ID('reports.CL_Audyt_Wewnetrzny', 'U') is not null drop table reports.CL_Audyt_Wewnetrzny    
  --create table reports.CL_Audyt_Wewnetrzny    
  --(   ID            int Identity(1,1)    
  --   ,Pracownik          varchar(100)    
  --   ,DataDecyzjiRRRRMC         int    
  --   , LiniaBiznesowa        varchar(100)    
  --   , NrClaim          varchar(100)    
  --   , NrKontraktu         varchar(100)    
  --   , TypKontraktu         varchar(100)    
  --   , TypUmowy          varchar(100)    
  --   , TypRoszczenia         varchar(100)    
  --   , StatusClaim         varchar(100)    
  --   , StatusKomponentu        varchar(100)    
  --   , StatusPaymentRequesta       varchar(100)    
  --   , KwotaPaymentRequesta       varchar(100)    
  --   , UzytkownikRejestrujacyKomponent    varchar(100)    
  --   , UzytkownikDecyzja        varchar(100)    
  --   , UzytkownikRejestrujacyWyplate     varchar(100)    
  --   , UzytkownikAkceptujacyWyplate     varchar(100)    
  --   , Kategoria          varchar(100)    
  --   , TimeStamp          datetime default GETDATE()    
  --)    
  --tworze tabelke z uwagami    
  --IF OBJECT_ID('reports.CL_Audyt_Wewnetrzny_Uwagi', 'U') is not null drop table reports.CL_Audyt_Wewnetrzny_Uwagi    
  --CREATE TABLE reports.CL_Audyt_Wewnetrzny_Uwagi (ID int Identity(1,1), DataDecyzjiRRRRMC int not null, Pracownik varchar(100) not null, FastTrack int, Odmowa int, AkceptacjeNaDrugaReke int, Akceptacje int  
  --, OpinieMedyczne int, SumaSpraw AS (FastTrack + Odmowa+ AkceptacjeNaDrugaReke + Akceptacje + OpinieMedyczne ) ,TimeStamp datetime default CURRENT_TIMESTAMP)    
  ----ALTER TABLE reports.CL_Audyt_Wewnetrzny_Uwagi  ADD CONSTRAINT PK_CL_AUD_WEWN_UW PRIMARY KEY (DataDecyzjiRRRRMC, Pracownik)    
  --alter table reports.CL_Audyt_Wewnetrzny_Uwagi add LosoweUzupelnienie int
  --alter table reports.CL_Audyt_Wewnetrzny_Uwagi drop column SumaSPraw
  --alter table reports.CL_Audyt_Wewnetrzny_Uwagi add SumaSpraw as (FastTrack + Odmowa+ AkceptacjeNaDrugaReke + Akceptacje + OpinieMedyczne + LosoweUzupelnienie)
  --delete reports.CL_Audyt_Wewnetrzny    
  --delete reports.CL_Audyt_Wewnetrzny_Uwagi    
