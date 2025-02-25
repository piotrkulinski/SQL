--#region [GetKSeFInvoiceMap]
GO
IF OBJECT_ID (N'dbo.GetKSeFInvoiceMap') IS NOT NULL
   DROP PROCEDURE [dbo].[GetKSeFInvoiceMap]
go
print 'Tworzê procedure multi tabelaryczn¹ [GetKSeFInvoiceMap]'
/*
exec [dbo].[GetKSeFInvoiceMap] @debug=1,@InvoiceBody=null
exec [dbo].[GetKSeFInvoiceMap] @InvoiceBody ='<Faktura xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://crd.gov.pl/wzor/2021/11/29/11089/"><Naglowek><KodFormularza kodSystemowy="FA (1)" wersjaSchemy="1-0E">FA</KodFormularza><WariantFormularza>1</WariantFormularza><DataWytworzeniaFa>2023-06-05T09:04:41Z</DataWytworzeniaFa><SystemInfo>Aplikacja Podatnika KSeF</SystemInfo></Naglowek><Podmiot1><DaneIdentyfikacyjne><NIP>1894466533</NIP><PelnaNazwa>Firma wystawiaj¹ca</PelnaNazwa><NazwaHandlowa>Firma wystawiaj¹ca</NazwaHandlowa></DaneIdentyfikacyjne><Adres><AdresPol><KodKraju>PL</KodKraju><Ulica>Jadwigów</Ulica><NrDomu>66</NrDomu><Miejscowosc>Jadwigów</Miejscowosc><KodPocztowy>97-200</KodPocztowy><Poczta>Tomaszów Mazowiecki</Poczta></AdresPol></Adres><Email>piotr.k@mail.com</Email></Podmiot1><Podmiot2><DaneIdentyfikacyjne><NIP>1147581153</NIP><PelnaNazwa>Powszechna Spó³dzienia Spo¿ywców Spo³em</PelnaNazwa><NazwaHandlowa>Powszechna Spó³dzienia Spo¿ywców Spo³em</NazwaHandlowa></DaneIdentyfikacyjne><Adres><AdresPol><KodKraju>PL</KodKraju><Ulica>Sowiñskiego</Ulica><NrDomu>61</NrDomu><Miejscowosc>Wyszków</Miejscowosc><KodPocztowy>07-200</KodPocztowy><Poczta>Wyszków</Poczta></AdresPol></Adres><Email>jkowal@email.com</Email><Telefon>875685675</Telefon><NrKlienta>AA0097</NrKlienta></Podmiot2><Fa><KodWaluty>PLN</KodWaluty><P_1>2023-06-05</P_1><P_1M>Jadwigów</P_1M><P_2>0004/2023/05</P_2><P_6>2023-06-05</P_6><P_13_1>32.52</P_13_1><P_14_1>7.48</P_14_1><P_15>40</P_15><Adnotacje><P_16>2</P_16><P_17>2</P_17><P_18>2</P_18><P_18A>2</P_18A><P_19>2</P_19><P_22>2</P_22><P_23>2</P_23><P_PMarzy>2</P_PMarzy></Adnotacje><RodzajFaktury>VAT</RodzajFaktury><FaWiersze><LiczbaWierszyFaktury>1</LiczbaWierszyFaktury><WartoscWierszyFaktury2>40</WartoscWierszyFaktury2><FaWiersz><NrWierszaFa>1</NrWierszaFa><P_7>Zgrzewka wody</P_7><DodatkoweInfo>Mapowanie</DodatkoweInfo><P_8A>opak</P_8A><P_8B>2</P_8B><P_9B>20</P_9B><P_11A>40</P_11A><P_12>23</P_12></FaWiersz></FaWiersze><Platnosc><Zaplacono>1</Zaplacono><DataZaplaty>2023-06-05</DataZaplaty><FormaPlatnosci>1</FormaPlatnosci></Platnosc></Fa></Faktura>'

--V2
exec [dbo].[GetKSeFInvoiceMap] @InvoiceBody = '<?xml version="1.0" encoding="windows-1250"?><Faktura xmlns="http://crd.gov.pl/wzor/2023/05/15/05151/" xmlns:edt="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Naglowek><KodFormularza kodSystemowy="FA (2)" wersjaSchemy="2-0E">FA</KodFormularza><WariantFormularza>2</WariantFormularza><DataWytworzeniaFa>2023-04-14T00:00:00</DataWytworzeniaFa><SystemInfo>GastroKlasykaSZEF</SystemInfo></Naglowek><Podmiot1><DaneIdentyfikacyjne><NIP>1147581153</NIP><Nazwa>Piotr Kuliñœki Firma na potrzeby testu KSeF Test KSeF</Nazwa></DaneIdentyfikacyjne><Adres><KodKraju>PL</KodKraju><AdresL1>Jadwigów 3333</AdresL1><AdresL2>97-200 Jadwigów</AdresL2></Adres><DaneKontaktowe/></Podmiot1><Podmiot2><DaneIdentyfikacyjne><NIP>5711692348</NIP><Nazwa>Fabryka Okien KONAL S.A</Nazwa></DaneIdentyfikacyjne><Adres><KodKraju>PL</KodKraju><AdresL1>Jeleñska 56</AdresL1><AdresL2>Lidzbark 13-230</AdresL2></Adres><DaneKontaktowe/></Podmiot2><Fa><KodWaluty>PLN</KodWaluty><P_1>2023-04-14</P_1><P_1M>Jadwigów</P_1M><P_2>15/2023</P_2><P_6>2023-04-14</P_6><P_13_1>1991.87</P_13_1><P_14_1>458.13</P_14_1><P_13_2>370.37</P_13_2><P_14_2>29.63</P_14_2><P_15>2850.00</P_15><Adnotacje><P_16>2</P_16><P_17>2</P_17><P_18>2</P_18><P_18A>2</P_18A><Zwolnienie><P_19N>1</P_19N></Zwolnienie><NoweSrodkiTransportu><P_22N>1</P_22N></NoweSrodkiTransportu><P_23>2</P_23><PMarzy><P_PMarzyN>1</P_PMarzyN></PMarzy></Adnotacje><RodzajFaktury>ROZ</RodzajFaktury><FakturaZaliczkowa><NrFaZaliczkowej>13/2023</NrFaZaliczkowej><NrKSeFFaZaliczkowej>1147581153-20230516-82C08A-2EBA2D-27</NrKSeFFaZaliczkowej></FakturaZaliczkowa><FakturaZaliczkowa><NrFaZaliczkowej>14/2023</NrFaZaliczkowej><NrKSeFFaZaliczkowej>1147581153-20230517-09A42D-12376C-34</NrKSeFFaZaliczkowej></FakturaZaliczkowa><FaWiersz><NrWierszaFa>1</NrWierszaFa><P_7>ZESTAW OBIADOWY 4.</P_7><Indeks>1503</Indeks><P_8A>szt</P_8A><P_8B>400.000</P_8B><P_9B>6.00</P_9B><P_11A>2400.00</P_11A><P_12>8</P_12></FaWiersz><FaWiersz><NrWierszaFa>2</NrWierszaFa><P_7>KAWA MOCHA</P_7><Indeks>1624</Indeks><P_8A>szt</P_8A><P_8B>500.000</P_8B><P_9B>10.90</P_9B><P_11A>5450.00</P_11A><P_12>23</P_12></FaWiersz><Rozliczenie><Odliczenia><Kwota>3000.00</Kwota><Powod>Numer faktury zaliczkowej 13/2023, Data wystawienia: 2023-04-14</Powod></Odliczenia><Odliczenia><Kwota>2000.00</Kwota><Powod>Numer faktury zaliczkowej 14/2023, Data wystawienia: 2023-04-14</Powod></Odliczenia><SumaOdliczen>5000.00</SumaOdliczen></Rozliczenie><Platnosc><Zaplacono>1</Zaplacono><DataZaplaty>2023-04-14</DataZaplaty><TerminPlatnosci><Termin>2023-04-14</Termin><TerminOpis>Gotówka</TerminOpis></TerminPlatnosci><FormaPlatnosci>1</FormaPlatnosci></Platnosc></Fa><Stopka><Informacje><StopkaFaktury>Stopka faktury Powinna pojawiæ siê w KSeF</StopkaFaktury></Informacje><Rejestry/></Stopka></Faktura>'
*/
go
CREATE PROCEDURE [dbo].[GetKSeFInvoiceMap] (
 @debug tinyint=0
,@InvoiceBody xml = null
) 
as begin
	begin try

	-- rozparsowanie faktury z KSeF do tabeli
	if (@InvoiceBody is null) begin 
		SELECT top 1
			@InvoiceBody = convert(xml,replace(resp.value('(.)[1]', 'nvarchar(max)'),'<?xml version="1.0" encoding="utf-8"?>',''))
			FROM KSeFCommunication t
		CROSS APPLY t.response.nodes('/ApiResponse/response') A(resp)
		where t.[type]='InvoiceBody' 
		order by timestamp desc -- zostatniego rekordu
	end
	
	if (@debug=1) begin
		select @InvoiceBody
	end
	
	declare @towary_dostawy table (
		 [TowarID] int --klasyka
		,[TowarNazwa] nvarchar(100) --klasyka
		,[TowarJm] char(3) --klasyka
		,[Zawartosc] decimal(12,4) default(0.00) --klasyka pobrane z mapowania
		,[NrWierszaFa] int
		,[Nazwa] nvarchar(100)
		,[Jm] varchar(5)
		,[ilosc] decimal(19,5)
		,[cena] decimal(19,2)
		,[wartosc] decimal(19,2)
		,[StawkaVat] varchar(7)
		,[CzyNetto] bit default(0)
		,[IsLoad] bit default(0)
		,[IDMagazynu] smallint default(0) --magazyn docelowy dla dostawy towaru
		,[IdMap] int default(0) --id mapowania, jeœli puste nie by³o na moment parsowania faktury KSeF
	)
	
	declare @dostawca table (
		 [NIP] varchar(30)
		,[PelnaNazwa] nvarchar(250)
		,[NazwaHandlowa] nvarchar(250)
		,[KodPocztowy] nvarchar(50)
		,[Miejscowosc] nvarchar(50)
		,[NrLokalu] nvarchar(50)
		,[NrDomu] nvarchar(50)
		,[Ulica] nvarchar(50)
		,[KodKraju] char(2)
		,[Email] nvarchar(60)
		,[Telefon] varchar(50)
		,[ImiePierwsze] nvarchar(50)
		,[Nazwisko] nvarchar(50)
		,[IDKontrahenta] char(6)
		,[TerminPlatnosci] varchar(10)
		,[DataFaktury] varchar(10)
		,[AdresL1] varchar(250) default('')
		,[AdresL2] varchar(250) default('')
	)
	
	select t.Nazwa,t.TowaruID,t.Jm,v.Procent,t.Precyzja
	into #tow_filter
	from towary t with(nolock)
	inner join VAT v with(nolock) on v.Numer=t.vat
	where t.RodzajTowaru=1 and t.Magazynowany=1 and t.Receptura=0 and t.CzyBlokada=0 
	order by t.nazwa
	create index tow_filter1 on #tow_filter(TowaruID)
	create index tow_filter2 on #tow_filter(Nazwa)

	declare @namespace varchar(max) = @InvoiceBody.value('namespace-uri((/*:Faktura)[1])','nvarchar(max)')
	declare @schema_v int = case when  (charindex('2021/11/29/11089',@namespace)>0) then 1 else 2 end

	
	if (@schema_v=1) begin
		;with xmlnamespaces(default 'http://crd.gov.pl/wzor/2021/11/29/11089/')
		insert into @towary_dostawy(
			[NrWierszaFa],[Nazwa],[Jm],[ilosc],[cena],[wartosc],[StawkaVat],[CzyNetto]
		)
		select distinct
			q.value('(NrWierszaFa)[1]','integer') [NrWierszaFa]
			,q.value('(P_7)[1]','nvarchar(50)') [Nazwa]
			,rtrim(ltrim(q.value('(P_8A)[1]','varchar(5)'))) [Jm]
			,q.value('(P_8B)[1]','decimal(19,5)') [ilosc]
			,case when q.exist('(P_9A)[1]')=1 then q.value('(P_9A)[1]','decimal(19,2)') else  q.value('(P_9B)[1]','decimal(19,2)') end [cena]
			,case when q.exist('(P_11A)[1]')=1 then q.value('(P_11A)[1]','decimal(19,2)') else q.value('(P_11)[1]','decimal(19,2)') end [wartosc]
			,q.value('(P_12)[1]','varchar(7)') [StawkaVat]
			,case when q.exist('(P_9A)[1]')=1 then 1 else 0 end [CzyNetto]
		from @InvoiceBody.nodes('/Faktura/Fa/FaWiersze/FaWiersz') as F(q)
	
		--;with xmlnamespaces(default 'http://crd.gov.pl/wzor/2021/11/29/11089/','http://www.w3.org/2001/XMLSchema-instance' as xsi,'http://www.w3.org/2001/XMLSchema' as xsd)
		;with xmlnamespaces(default 'http://crd.gov.pl/wzor/2021/11/29/11089/')
		insert into @dostawca(
			 [NIP],[PelnaNazwa],[NazwaHandlowa],[KodPocztowy],[Miejscowosc]
			,[NrLokalu],[NrDomu],[Ulica],[KodKraju],[Email]
			,[Telefon],[ImiePierwsze],[Nazwisko]
			,[TerminPlatnosci]
			,[DataFaktury]
		)
		select 
			 dane.value('(NIP)[1]','varchar(30)') [NIP]
			,dane.value('(PelnaNazwa)[1]','nvarchar(250)') [PelnaNazwa]
			,dane.value('(NazwaHandlowa)[1]','nvarchar(250)') [NazwaHandlowa]
			------------
			,adres.value('(KodPocztowy)[1]','nvarchar(50)') [KodPocztowy]
			,adres.value('(Miejscowosc)[1]','nvarchar(50)') [Miejscowosc]
			,adres.value('(NrLokalu)[1]','nvarchar(50)') [NrLokalu]
			,adres.value('(NrDomu)[1]','nvarchar(50)') [NrDomu]
			,adres.value('(Ulica)[1]','nvarchar(70)') [Ulica]
			,adres.value('(KodKraju)[1]','char(2)') [KodKraju]
			------------
			,addit.value('(Email)[1]','nvarchar(50)') [Email]
			,addit.value('(Telefon)[1]','nvarchar(50)') [Telefon]
			------------
			,isnull(dane.value('(ImiePierwsze)[1]','varchar(50)'),'') [ImiePierwsze]
			,isnull(dane.value('(Nazwisko)[1]','varchar(50)'),'') [Nazwisko]
			,isnull(faktura.value('(./Platnosc/TerminyPlatnosci/TerminPlatnosci)[1]','varchar(10)'),'') [TerminPlatnosci]
			,isnull(faktura.value('(P_6)[1]','varchar(10)'),'') [DataFaktury]
		from @InvoiceBody.nodes('/Faktura/Podmiot1') as t(addit)
		cross apply @InvoiceBody.nodes('/Faktura/Podmiot1/Adres/AdresPol') as a(adres)
		cross apply @InvoiceBody.nodes('/Faktura/Podmiot1/DaneIdentyfikacyjne') as b(dane)
		cross apply @InvoiceBody.nodes('/Faktura/Fa') as d(faktura)	
	end
	
	if (@schema_v=2) begin
		print 'FA (2)'
		;with xmlnamespaces(default 'http://crd.gov.pl/wzor/2023/06/29/12648/', 'http://crd.gov.pl/wzor/2023/06/29/12648/' as tns)
		insert into @towary_dostawy(
			[NrWierszaFa],[Nazwa],[Jm],[ilosc],[cena],[wartosc],[StawkaVat],[CzyNetto]
		)
		select distinct
			q.value('(NrWierszaFa)[1]','integer') [NrWierszaFa]
			,q.value('(P_7)[1]','nvarchar(50)') [Nazwa]
			,rtrim(ltrim(q.value('(P_8A)[1]','varchar(5)'))) [Jm]
			,q.value('(P_8B)[1]','decimal(19,5)') [ilosc]
			,case when q.exist('(P_9A)[1]')=1 then q.value('(P_9A)[1]','decimal(19,2)') else  q.value('(P_9B)[1]','decimal(19,2)') end [cena]
			,case when q.exist('(P_11A)[1]')=1 then q.value('(P_11A)[1]','decimal(19,2)') else q.value('(P_11)[1]','decimal(19,2)') end [wartosc]
			,q.value('(P_12)[1]','varchar(7)') [StawkaVat]
			,case when q.exist('(P_9A)[1]')=1 then 1 else 0 end [CzyNetto]
		from @InvoiceBody.nodes('/Faktura/Fa/FaWiersz') as F(q)

		;with xmlnamespaces(default 'http://crd.gov.pl/wzor/2023/06/29/12648/', 'http://crd.gov.pl/wzor/2023/06/29/12648/' as tns)
		insert into @dostawca(
			 [NIP],[PelnaNazwa],[NazwaHandlowa],[KodPocztowy],[Miejscowosc]
			,[NrLokalu],[NrDomu],[Ulica],[KodKraju],[Email]
			,[Telefon],[ImiePierwsze],[Nazwisko]
			,[TerminPlatnosci],[DataFaktury]
			,[AdresL1],[AdresL2]
		)
		select 
			 [NIP] = dane.value('(NIP)[1]','varchar(30)') 
			,[PelnaNazwa] = dane.value('(Nazwa)[1]','nvarchar(250)') 
			,[NazwaHandlowa] = ''
			------------
			,[KodPocztowy] = '' 
			,[Miejscowosc] = '' 
			,[NrLokalu] = ''
			,[NrDomu] = ''
			,[Ulica] = ''
			,[KodKraju] = adres.value('(KodKraju)[1]','char(2)') 
			------------
			,[Email] = pd.value('(DaneKontaktowe/Email)[1]','nvarchar(50)') 
			,[Telefon] = pd.value('(DaneKontaktowe/Telefon)[1]','nvarchar(50)') 
			------------
			,[ImiePierwsze] = '' 
			,[Nazwisko] = ''
			,[TerminPlatnosci] = ''
			,[DataFaktury] = isnull(faktura.value('(P_6)[1]','varchar(10)'),'') 
			,[AdresL1] = isnull(adres.value('(AdresL1)[1]','varchar(250)'),'')
			,[AdresL2] = isnull(adres.value('(AdresL2)[1]','varchar(250)'),'')
		from @InvoiceBody.nodes('/Faktura/Podmiot1') as t(pd)
		--cross apply @InvoiceBody.nodes('/Faktura/Podmiot1/DaneKontaktowe') as e(addit)
		cross apply @InvoiceBody.nodes('/Faktura/Podmiot1/Adres') as a(adres)
		cross apply @InvoiceBody.nodes('/Faktura/Podmiot1/DaneIdentyfikacyjne') as b(dane)	
		cross apply @InvoiceBody.nodes('/Faktura/Fa') as d(faktura)	

		declare @idx int
		update @dostawca SET
			@idx = PATINDEX('%[0-9][0-9]-[0-9][0-9][0-9]%',AdresL1+AdresL2)
			,KodPocztowy = case when @idx>0 then substring(AdresL1+AdresL2,@idx,6) else '' end 
		where isnull(KodPocztowy,'')=''

	end

	--test 
	-- if (@schema_v=1) begin
	-- 	update @dostawca set AdresL1=ltrim(rtrim(KodPocztowy))+' '+ltrim(rtrim(Miejscowosc)),AdresL2=ltrim(rtrim(Ulica))+' '+ltrim(rtrim(NrDomu))
	-- end

	-- aktualizacja o towary mo¿iwe to zmapowania z kartotek¹
	update @towary_dostawy set 
		  [TowarId]=t.TowaruID
		, [TowarNazwa]=t.Nazwa
		, [TowarJm]=t.Jm
		, [Zawartosc]=1
		, [IsLoad]=1
		--, [IDMagazynu]=tm.IDMagazynu, podmapowaæ domyœlny magazyn usera po SPID i sesji
	from @towary_dostawy td
	join #tow_filter t with(nolock,index(tow_filter2)) on t.Nazwa=td.Nazwa --and t.RodzajTowaru=1 and t.Magazynowany=1 and t.Receptura=0 and t.CzyBlokada=0 
	
	-- aktualizacja o towary zamapowane dla wybranego dostawcy
	update @towary_dostawy set 
		  [TowarId]=tm.TowarID
		, [TowarNazwa]=t.Nazwa
		, [TowarJm]=t.Jm
		, [Zawartosc]=isnull(tm.Zawartosc,1)
		, [IsLoad]=1
		, [IDMagazynu]=tm.IDMagazynu
		, [IdMap]=tm.id
	from @towary_dostawy td
	join @dostawca d on 1=1
	join KontrahenciFirmy kf with(nolock) on kf.IDKontrahenta=d.IDKontrahenta or kf.NumerIdentyfikacyjny=d.NIP
	join TowaryMapowanie tm with(nolock) on tm.KontrahentID=kf.IDKontrahenta and tm.Nazwa=td.Nazwa and tm.Jm=td.jm
	join #tow_filter t with(nolock,index(tow_filter1)) on t.TowaruID=tm.TowarID

	update @towary_dostawy
	set StawkaVat = case when StawkaVat='zw' then StawkaVat else StawkaVat+'%' END

	-- aktualizacja dostawcy
	update @dostawca set 
		 [IDKontrahenta]=kf.IDKontrahenta
		,[Email]=ISNULL(d.[EMail],kf.AdresEMail)
		,[Telefon]=ISNULL(d.[Telefon],kf.Telefon)
		,[NrLokalu]=ISNULL(d.[NrLokalu],kf.NumerMieszkania)
		,[TerminPlatnosci]=case when ltrim(rtrim(isnull([TerminPlatnosci],'')))='' then convert(varchar(10),getdate(),120) else [TerminPlatnosci] end
	from @dostawca d
	inner join KontrahenciFirmy kf with(nolock) on kf.NumerIdentyfikacyjny=d.NIP

	select * from @towary_dostawy order by [NrWierszaFa]
	select * from @dostawca 
	select * from #tow_filter with(nolock,index(tow_filter2))
	
	end try
	
	begin catch
		print 'B³¹d podczas importu faktury z KSeF'
		RAISERROR ('B³¹d podczas importu faktury z KSeF', 16, 1) WITH NOWAIT, SETERROR
	end catch
end
go