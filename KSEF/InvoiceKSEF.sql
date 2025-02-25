--#region [InvoiceKSEF]
go
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[InvoiceKSEF]') and xtype='P')
drop procedure [dbo].[InvoiceKSEF]
GO
print 'Tworze procedure InvoiceKSEF'
GO
CREATE PROCEDURE [dbo].[InvoiceKSEF]
(
	 @id bigint = 0
	,@kodSystemowy int = 2 
	,@debug int = 0
)
as begin
set nocount on

--declare @debug int = 0
declare @application varchar(10)='SZEF' 

-- 1 - 'FA (1)'
-- 2 - 'FA (2)'
--declare @kodSystemowy int = 1 
declare @wersjaSchemy varchar(4)= '1-0E' --str(@kodSystemowy,1)+'-0E'
declare @x_czy_info_rabat_fv bit = isnull((select case when p.Tekstowa='T' then 1 else 0 end from Parametry p with(nolock) where p.zmienna='x_czy_info_rabat_fv'),0)

declare @kodlokalizacji char(2) = isnull((select top 1 tekstowa from parametry where zmienna='x_kodlokalizacji'),'AA')
set @application = case when (@kodlokalizacji>='AA' and @id>=100000000000000) then 'SZEF' else 'POS' end

declare @TypDokumentu varchar(10)
declare @CzyMetodaKasowa int = isnull((
	select top 1 (case when isnull(liczbowa,'')='' then 2 else 1 end) 
	from parametry 
	where zmienna='x_czymetodakasowa'),2)

declare @NaglowekFaktury [InvoiceHeader]
declare @NaglowekFakturyKorygowanej [InvoiceHeader]
declare @PozycjeFaktury [InvoicePosition] 
declare @NaglowkiZaliczek [InvoiceHeader]

declare @firma table (
	 Nazwa1	varchar(200)
	,Nazwa2	varchar(200)
	,Nazwa3	varchar(200)
	,Miejscowosc varchar(200)
	,Ulica	varchar(200)
	,Bank varchar(200)
	,Konto varchar(200)
	,Nip	varchar(20)
	,EUNip varchar(20)
	,Telefon varchar(50)
	,MiejsceFaktur varchar(100)
	,StopkaFaktury varchar(5000)
	,StalyDopisekDoFaktury varchar(4000)
	,NrDomu varchar(10)
	,KodPocztowy varchar(6)
	,email varchar(50)
	,BDO varchar(20)
	,REGON varchar(20)
	,KodKraju varchar(4)
	,Imie varchar(40)
	,Nazwisko varchar(50)
)

declare @totalizer     
table (    
  IDDokumentu bigint,
  SymbVat varchar(2),    
  Konto varchar(10),    
  StawkaVat decimal(9,2),    
  CzySprzedazWedlugNetto int,
  pozycji int,
  netto decimal(12,2),    
  brutto decimal(12,2),    
  vat decimal(12,2),    
  yvat decimal(12,2),    
  kurs decimal(19,5),
  Typ int default 0 -- 1 - rozliczenie (pomniejszenie faktur o zaliczki)
)  

-- warto eksportowaæ te¿ faktury z POS, wiêc dla nich zostan¹ dodane opcje maskuj¹ce/mapuj¹ce
--- synonim dla funkcji dbo.PozycjeDoWydruku aby raz pobiera³a dane z tabel szefa innym razem posowych
if OBJECT_ID('MapPozycjeDoWydruku')<>0 begin
	drop synonym MapPozycjeDoWydruku
end

declare @map varchar(250) = 'create synonym MapPozycjeDoWydruku for '
if (@application='POS') begin
	set @map+='dbo.POSPozycjeDoWydruku'
	
	insert into @NaglowekFaktury
	select 
		 h.ID,@application,h.KasyID,case when h.TYP='F' then 'F.vat' else 'KOREK' end,h.NUMER
		,convert(datetime,h.Data,121) [DataDokumentu],convert(datetime,h.DataSP,121) [DataSprzedazy],h.FormaZapla [FormaPlatnosci],convert(datetime,h.terplll,121) [TerminPlatnosci],h.komenxx [Opis]
		,0 [ZmianaZalogi],0 [WalutyID], 1 [Panstwo], convert(datetime,h.Data,121) [DataModyfikacji],0 [NumerDuplikatu]
		,h.KURSWALUTY [KursWalutySprzedazy], h.cokor [KorektaDoDokumentuID],0 [ZaliczkaDoDokumentu], h.wart_total [WartoscDS],h.NumerPelny
		,0 [RodzajWydrukuDokumentu],0 [NrZamowienia],h.NIP,h.kodkl,case when isnull(h.kododb,'')='' then null else h.kododb end
		,0 [CzyDrukowany],0 [CzyOdczytZKasECR],0 [CzySprzedazWedlugNetto],0 [CzyDokumentProforma]
		,case when h.kodkl='' and h.kododb='' then 1 else 0 end [CzyFakturaUproszczona],0 [CzyFakturaWewnetrzna],0 [CzyFakturaZaliczkowa],0 [CzyFakturaVatMarza]
	from rejvat h with(nolock)
	where h.ID=@ID

	-- za³adowanie g³ówki faktury któr¹ skorygowaliœmy
	if exists (select top 1 1 from @NaglowekFaktury where [KorektaDoDokumentuID]<>0) begin
		insert into @NaglowekFakturyKorygowanej
		select top 1
		 h.ID,@application,h.KasyID,case when h.TYP='F' then 'F.vat' else 'KOREK' end,h.NUMER
		,convert(datetime,h.Data,121) [DataDokumentu],convert(datetime,h.DataSP,121) [DataSprzedazy],h.FormaZapla [FormaPlatnosci],convert(datetime,h.terplll,121) [TerminPlatnosci],h.komenxx [Opis]
		,0 [ZmianaZalogi],0 [WalutyID], 1 [Panstwo], convert(datetime,h.Data,121) [DataModyfikacji],0 [NumerDuplikatu]
		,h.KURSWALUTY [KursWalutySprzedazy], h.cokor [KorektaDoDokumentuID],0 [ZaliczkaDoDokumentu], h.wart_total [WartoscDS],h.NumerPelny
		,0 [RodzajWydrukuDokumentu],0 [NrZamowienia],h.NIP,h.kodkl,case when isnull(h.kododb,'')='' then null else h.kododb end
		,0 [CzyDrukowany],0 [CzyOdczytZKasECR],0 [CzySprzedazWedlugNetto],0 [CzyDokumentProforma]
		,case when h.kodkl='' and h.kododb='' then 1 else 0 end [CzyFakturaUproszczona],0 [CzyFakturaWewnetrzna],0 [CzyFakturaZaliczkowa],0 [CzyFakturaVatMarza]
		from rejvat h with(nolock)
		join @NaglowekFaktury kor on kor.KorektaDoDokumentuID=h.lacznik and kor.KasyID=h.KasyID
	end
end 
else begin
	set @map+='dbo.EnvelopePozycjeDoWydruku'
	
	insert into @NaglowekFaktury
	select 
		 IDDokumentu,@application,KasyID,TypDokumentu,NumerDokumentu
		,DataDokumentu,DataSprzedazy,FormaPlatnosci,TerminPlatnosci,Opis
		,ZmianaZalogi,WalutyID,Panstwo,DataModyfikacji,NumerDuplikatu
		,KursWalutySprzedazy,KorektaDoDokumentuID,ZaliczkaDoDokumentu,WartoscDS,NumerPelny
		,RodzajWydrukuDokumentu,NrZamowienia,KontrahentNIP,Kontrahent,Odbiorca
		,CzyDrukowany,CzyOdczytZKasECR,CzySprzedazWedlugNetto,CzyDokumentProforma
		,CzyFakturaUproszczona,CzyFakturaWewnetrzna,CzyFakturaZaliczkowa,CzyFakturaVatMarza
	from nds with(nolock)
	where nds.IDDokumentu=@ID

	-- za³adowanie g³ówki faktury któr¹ skorygowaliœmy
	if exists (select top 1 1 from @NaglowekFaktury where [KorektaDoDokumentuID]<>0) begin
		insert into @NaglowekFakturyKorygowanej
		select 
			 nds.IDDokumentu,@application,nds.KasyID,nds.TypDokumentu,nds.NumerDokumentu
			,nds.DataDokumentu,nds.DataSprzedazy,nds.FormaPlatnosci,nds.TerminPlatnosci,nds.Opis
			,nds.ZmianaZalogi,nds.WalutyID,nds.Panstwo,nds.DataModyfikacji,nds.NumerDuplikatu
			,nds.KursWalutySprzedazy,nds.KorektaDoDokumentuID,nds.ZaliczkaDoDokumentu,nds.WartoscDS,nds.NumerPelny
			,nds.RodzajWydrukuDokumentu,nds.NrZamowienia,nds.KontrahentNIP,nds.Kontrahent,nds.Odbiorca
			,nds.CzyDrukowany,nds.CzyOdczytZKasECR,nds.CzySprzedazWedlugNetto,nds.CzyDokumentProforma
			,nds.CzyFakturaUproszczona,nds.CzyFakturaWewnetrzna,nds.CzyFakturaZaliczkowa,nds.CzyFakturaVatMarza
		from nds with(nolock)
		join @NaglowekFaktury kor on kor.KorektaDoDokumentuID=nds.IDDokumentu
	end

	insert into @NaglowkiZaliczek
	select 
		 nds.IDDokumentu,@application,nds.KasyID,nds.TypDokumentu,nds.NumerDokumentu
		,nds.DataDokumentu,nds.DataSprzedazy,nds.FormaPlatnosci,nds.TerminPlatnosci, zal.Opis
		,nds.ZmianaZalogi,nds.WalutyID,nds.Panstwo,nds.DataModyfikacji,nds.NumerDuplikatu
		,nds.KursWalutySprzedazy,nds.KorektaDoDokumentuID,nds.ZaliczkaDoDokumentu,nds.WartoscDS,nds.NumerPelny
		,nds.RodzajWydrukuDokumentu,nds.NrZamowienia,nds.KontrahentNIP,nds.Kontrahent,nds.Odbiorca
		,nds.CzyDrukowany,nds.CzyOdczytZKasECR,nds.CzySprzedazWedlugNetto,nds.CzyDokumentProforma
		,nds.CzyFakturaUproszczona,nds.CzyFakturaWewnetrzna,nds.CzyFakturaZaliczkowa,nds.CzyFakturaVatMarza
	from nds with(nolock)
	inner join dbo.OpisFakturZaliczkowych( @ID ) zal on zal.iddokumentu=nds.IDDOkumentu

end
--print @map
execute(@map)

insert into @firma(
	 Nazwa1,Nazwa2,Nazwa3
	,Miejscowosc,Ulica,NrDomu
	,Bank,Konto,f.Nip,EUNip,Telefon,MiejsceFaktur,StopkaFaktury,email
	,BDO
	,REGON,KodKraju
	,imie,nazwisko
	,KodPocztowy
)
select 
	 isnull(kf.Nazwa1,f.Nazwa1),isnull(kf.Nazwa2,f.Nazwa2),f.Nazwa3
	,isnull(kf.Miejscowosc, f.Adres1),isnull(kf.Ulica,f.Adres2),isnull(kf.NumerDomu,null)
	,f.Bank
	,case when rtrim(isnull(f.Konto,''))='' then kf.KontoBankowe else f.Konto end
	,replace(replace(isnull(kf.NumerIdentyfikacyjny,f.Nip),' ',''),'-','')
	,isnull(kf.EuroNIP,f.EUNip),isnull(kf.Telefon,f.Telefon),case when isnull(f.MiejsceFaktur,'')='' then isnull(kf.Miejscowosc, f.Adres1) else kf.Miejscowosc end
	,f.StopkaFaktury,kf.AdresEMail
	,case when patindex('%BDO: [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%',StopkaFaktury)>0 then substring(StopkaFaktury,patindex('%BDO: [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%',StopkaFaktury)+5,9) else null end
	,kf.REGON,isnull(p.Kod,'PL')
	,case when kf.kontakt<>'' and charindex(' ',kf.kontakt)>0 then substring(kf.kontakt,0,charindex(' ',kf.kontakt)) else null end
	,case when kf.kontakt<>'' and charindex(' ',kf.kontakt)>0 then substring(kf.kontakt,charindex(' ',kf.kontakt)+1,len(kontakt)) else null end
	,kf.KodPocztowy
from @NaglowekFaktury nds
join Kasy k with(nolock) on k.IDKasy=nds.KasyID
join Firmy f with(nolock) on f.ID=k.Firma and f.flgDeleted=0
left join KontrahenciFirmy kf with(nolock) on kf.IDKontrahenta=f.KontrahentaID
left join Panstwa p with(nolock) on p.IDPanstwa=kf.PanstwaID

update @firma set 
StalyDopisekDoFaktury = isnull((select top 1 opis
			from parametry p with(nolock)
			where p.zmienna in ('x_stopkafaktur','x_stalydopisekdofaktury') and isnull(p.opis,'')<>''
			),null)

-- pobranie zunifikowanych pozycji dla faktur z szefa i posa
insert into @PozycjeFaktury exec [dbo].[MapPozycjeDoWydruku] @ID 

select @TypDokumentu = TypDokumentu from @NaglowekFaktury 
if (@TypDokumentu<>'KOREK' and @application<>'POS') -- bo korekta ma ju¿ w sobie pozycje +/i i nie trzeba dodatkowo komensowaæ innych dokumentów
begin

if exists(select * from @NaglowkiZaliczek) begin
	declare @current int = 0
	declare @sign int = -1
	declare @iddokumentu as bigint = 0
	declare @doksprz as InvoicePosition

	while (1=1) begin
		set @iddokumentu=0
		select top 1 
			@current=id,
			@iddokumentu=iddokumentu 
		from @NaglowkiZaliczek 
		where id>@current

		if (@iddokumentu=0) break

		insert into @doksprz
		exec MapPozycjeDoWydruku @iddokumentu, '', '', 1 ,0 ,1,1
  
		insert into @PozycjeFaktury
		select   
			z.iddokumentu,p.pozycja,-1, p.nazwa, p.jm, p.cena, p.Vat, @sign*p.Ilosc, @sign*p.Wartosc, p.cena_nomin, p.rabat, p.StawkaVAT,     
			p.sww, p.zwolniony, p.plu, p.modyf, p.posilek, p.czykoryg, case when p.OpisPozycji='' then null else left(p.OpisPozycji,50) end, p.jmpl, p.czyzal, p.Fp,     
			p.jmpl1, p.jmde, p.jmen, p.SymbVat, p.CzyUsluga, p.FlgTemp, p.MaxTemp, p.DataSpozycia, p.Indeks_m,    
			p.CzySprzedazWedlugNetto, @sign*p.XNetto, @sign*p.XBrutto, @sign*p.XVat, p.XCenaN, p.XCenaB, p.Zgrupowano   
		from @NaglowkiZaliczek z 
		cross apply @doksprz p
		where z.id=@current

		delete from @doksprz
	end
end
end

drop synonym MapPozycjeDoWydruku

insert into @totalizer(
	 IDDokumentu,SymbVat,Konto,StawkaVat,pozycji,CzySprzedazWedlugNetto
	,netto,brutto
)
select 
	 p.IDDokumentu,max(p.symbvat),max(v.KontoKsiegowe),max(p.stawkavat),count(p.IDDokumentu),p.CzySprzedazWedlugNetto
	,sum(case when p.CzySprzedazWedlugNetto=1 then p.xnetto else 0 end ),sum(case when p.CzySprzedazWedlugNetto=0 then p.xbrutto else 0 end)   
from @PozycjeFaktury p    
left join vat v on v.Numer=p.vat    
group by p.IDDokumentu,p.CzySprzedazWedlugNetto, p.vat  

declare @vat_total decimal(12,2)
update @totalizer set 
	  @vat_total = case when CzySprzedazWedlugNetto=1 then round(netto * stawkavat/100,2) else round(brutto * stawkavat/(stawkavat+100) ,2) end
    , brutto = case when CzySprzedazWedlugNetto=1 then netto+@vat_total else brutto end
    , netto = case when CzySprzedazWedlugNetto=1 then netto     else brutto-@vat_total end
	, vat = @vat_total

insert into @totalizer(IDDokumentu,Konto,SymbVat,stawkavat,pozycji,CzySprzedazWedlugNetto,netto,brutto,vat)    
select max(IDDokumentu),N'RAZEM','X',-2,sum(pozycji),max(CzySprzedazWedlugNetto),sum(x.netto),sum(x.brutto),sum(x.vat)    
from @totalizer x    
group by x.IDDokumentu,x.CzySprzedazWedlugNetto  

declare @count_poz int = isnull((select count(*) from @PozycjeFaktury where IDDokumentu = @ID),0)
insert into @totalizer(Typ,IDDokumentu,Konto,SymbVat,stawkavat,pozycji,CzySprzedazWedlugNetto,netto,brutto,vat)    
select 1,@ID,Konto,SymbVat,stawkavat,@count_poz /*sum(pozycji)*/,max(CzySprzedazWedlugNetto),sum(x.netto),sum(x.brutto),sum(x.vat)    
from @totalizer x
group by x.Konto,x.SymbVat,stawkavat,x.CzySprzedazWedlugNetto  

-- pozycje korekty musz¹ byæ odwrócone, najpierw pozycja korygowana na (-), póŸniej koryguj¹ca na (+)
-- dodatkowo dla nowych pozycji, musi byæ dodana równie¿ pozycja z iloœci¹ i wartoœci¹ zero, jako pozycja korygowana
if (@TypDokumentu='KOREK') begin
	
	if (@debug=1) begin
	    exec dbo.ConvertKorekToKSEF @PozycjeFaktury
    end
	-- todo: tu warto siê jeszcze przyjrzeæ na ró¿nych "konfiguracjach" korekty
	if (@application<>'POS') begin
		declare @convertpos InvoicePosition
		insert into @convertpos	exec dbo.ConvertKorekToKSEF @PozycjeFaktury
		delete from @PozycjeFaktury
		insert into @PozycjeFaktury select * from @convertpos order by nr_poz_dok
		delete from @convertpos
	end
	-- ponowne przeliczenie pozycji
	set @count_poz = isnull((select count(*) from @PozycjeFaktury where IDDokumentu = @ID),0)
	update @totalizer set pozycji=@count_poz
end
--set @debug=1
if (@debug=1) begin
 select '@Firma',* from @Firma
 select '@NaglowekFaktury',* from @NaglowekFaktury
 select '@NaglowekFakturyKorygowanej',* from @NaglowekFakturyKorygowanej
 select '@PozycjeFaktury',* from @PozycjeFaktury
 select '@NaglowkiZaliczek',* from @NaglowkiZaliczek
 select '@totalizer',* from @totalizer order by IDDokumentu,typ,SymbVat
end
declare @DokumentRozliczeniowy tinyint = isnull((select top 1 count(*) from @NaglowkiZaliczek),0)

declare @cRequest xml

if (@kodSystemowy=1) begin
	select @cRequest = 
	(
	   select
		(
			SELECT top 1
				"KodFormularza/@kodSystemowy"='FA ('+str(@kodSystemowy,1)+')',
				"KodFormularza/@wersjaSchemy"=@wersjaSchemy,
				'FA' [KodFormularza],
				@kodSystemowy AS WariantFormularza,
				CONVERT(varchar,nds.DataDokumentu,127) [DataWytworzeniaFa], 
				'GastroKlasyka'+@application AS SystemInfo
			from @NaglowekFaktury nds 
			FOR XML PATH(''), ROOT('Naglowek'), TYPE
		)
		,(
			SELECT 
				(	-- FA (1) DaneIdentyfikacyjne
					SELECT
						 [NIP] = f.Nip
						,[PelnaNazwa] = 
							isnull(f.Nazwa1,'')
							+(case when isnull(f.Nazwa2,'')='' then '' else ' '+f.Nazwa2 end)
							+(case when isnull(f.Nazwa3,'')='' then '' else ' '+f.Nazwa3 end)
						
					where @kodSystemowy=1
					FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
				)
				,(	
					SELECT
						(
							SELECT								
								 f.KodKraju [KodKraju]
								,f.Ulica  [Ulica]
								,f.NrDomu [NrDomu]
								,f.Miejscowosc [Miejscowosc]
								,f.KodPocztowy [KodPocztowy]
							where @kodSystemowy=1
							FOR XML PATH(''), ROOT('AdresPol'), TYPE
						)
					FOR XML PATH(''), ROOT('Adres'), TYPE
				)
				,case when isnull(f.email,'')='' then null else f.email end [Email]
				,case when isnull(f.Telefon,'')='' then null else f.Telefon end [Telefon]
				from @firma f			
			FOR XML PATH(''), ROOT('Podmiot1'), TYPE
		)
		,( -- Podmiot2
			SELECT 
				case when (nip.Ustawiono&2)=2 then nip.Prefix else null end [PrefiksNabywcy]
				,(	
					SELECT
						 [BrakID] = case when nip.Ustawiono=0 then 1 else null end
						,[NIP] = case 
									when isnull(nip.Ustawiono,0)=0 then (case when isnull(nds1.KontrahentNIP,'')='' then null else nds1.KontrahentNIP end) 
									when (nip.Ustawiono&2)=2 then nip.KartotekaUnijny
									else isnull(nip.Szukany,nip.KartotekaPolski) 
								end 
						,[PelnaNazwa] = case 
										when isnull(nip.Ustawiono,0)=0 then kf.Nazwa1 
										else rtrim(ltrim(isnull(kf.Nazwa1,'')+' '+ltrim(rtrim(isnull(kf.Nazwa2,'')))))
										end														
						 ,case when nip.Ustawiono=0
							then case 
								  when isnull(kf.kontakt,'')<>'' and charindex(' ',kf.kontakt)>0 then substring(kf.kontakt,0,charindex(' ',kf.kontakt)) 
								  else null --kf.Nazwa1 
								end
							else null
						 end [ImiePierwsze] --tylko jeœli nie ma NIP-u (fizyczna)
						 ,case when nip.Ustawiono=0
							then case 
								  when isnull(kf.kontakt,'')<>'' and charindex(' ',kf.kontakt)>0 then substring(kf.kontakt,charindex(' ',kf.kontakt)+1,len(kontakt))
								  else null --kf.Nazwa2 
								end
							else null
						 end [Nazwisko] --tylko jeœli nie ma NIP-u (fizyczna)
					FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
				)
				,(	
					SELECT
						( --FA(1)
							SELECT
								 left(isnull(p.Kod,'PL'),3) [KodKraju]
								,case when isnull(kf.Ulica,'')='' then null else kf.Ulica end  [Ulica]
								,case when isnull(kf.NumerDomu,'')='' then '0' else kf.NumerDomu end  [NrDomu]
								,case when isnull(kf.Miejscowosc,'')='' then (case when isnull(kf.Poczta,'')='' then null else kf.Poczta end) else kf.Miejscowosc end [Miejscowosc]
								,case when isnull(kf.KodPocztowy,'')='' or isnull(kf.Miejscowosc,'')='' then null else kf.KodPocztowy end [KodPocztowy]
							where  @kodSystemowy=1
							FOR XML PATH(''), ROOT('AdresPol'), TYPE
						)
					from @NaglowekFaktury fk 
					left join KontrahenciFirmy kf on kf.IDKontrahenta=isnull(case when ltrim(rtrim(isnull(fk.odbiorca,'')))='' then null else fk.odbiorca end,fk.Kontrahent)
					left join Panstwa p with(nolock) on p.IDPanstwa=kf.PanstwaID
					where kf.IDKontrahenta is not null
					FOR XML PATH(''), ROOT('Adres'), TYPE
				)
				,case when isnull(kf.AdresEMail,'')='' then null else kf.AdresEMail end [Email]
				,case when isnull(kf.Telefon,'')='' then null else kf.Telefon end [Telefon]
				,case when isnull(kf.IndeksZewnetrzny,'')='' then null else kf.IndeksZewnetrzny end [NrKlienta]
				from @NaglowekFaktury nds1
				left join [dbo].[DajNipKontrahenta](default,default) nip on nip.IDKontrahenta=nds1.Kontrahent
				left join KontrahenciFirmy kf on kf.IDKontrahenta=nip.IDKontrahenta --.Kontrahent	
				 --left join KontrahenciFirmy kf on kf.IDKontrahenta=nds.Kontrahent
			FOR XML PATH(''), ROOT('Podmiot2'), TYPE
		)
		-- ,( -- Podmiot3
		-- 	SELECT 
		-- 		case when (nip.Ustawiono&2)=2 then nip.Prefix else null end [PrefiksNabywcy]
		-- 		,( -- DaneIdentyfikacyjne
		-- 			SELECT
		-- 			 [BrakID] = case when nip.Ustawiono=0 then 1 else null end
		-- 			,[NIP] = case 
		-- 						when isnull(nip.Ustawiono,0)=0 then (case when isnull(nds1.KontrahentNIP,'')='' then null else nds1.KontrahentNIP end) 
		-- 						when (nip.Ustawiono&2)=2 then nip.KartotekaUnijny
		-- 						else isnull(nip.Szukany,nip.KartotekaPolski) 
		-- 					end 
		-- 			,[PelnaNazwa] = case 
		-- 							when isnull(nip.Ustawiono,0)=0 then kfo.Nazwa1 
		-- 							else isnull(kfo.Nazwa1,'')+(case when isnull(kfo.Nazwa2,'')='' then '' else ' '+kfo.Nazwa2 end) 
		-- 							end									
		-- 			 ,case when nip.Ustawiono=0
		-- 				then case 
		-- 					  when isnull(kfo.kontakt,'')<>'' and charindex(' ',kfo.kontakt)>0 then substring(kfo.kontakt,0,charindex(' ',kfo.kontakt)) 
		-- 					  else null --kf.Nazwa1 
		-- 					end
		-- 				else null
		-- 			  end [ImiePierwsze] --tylko jeœli nie ma NIP-u (fizyczna)
		-- 			 ,case when nip.Ustawiono=0
		-- 				then case 
		-- 					  when isnull(kfo.kontakt,'')<>'' and charindex(' ',kfo.kontakt)>0 then substring(kfo.kontakt,charindex(' ',kfo.kontakt)+1,len(kontakt))
		-- 					  else null --kf.Nazwa2 
		-- 					end
		-- 				else null
		-- 		 	end [Nazwisko] --tylko jeœli nie ma NIP-u (fizyczna)
		-- 			FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
		-- 	     )
		-- ,( --Adres
		-- 	SELECT
		-- 		( --AdresPol
		-- 			SELECT
		-- 				 left(isnull(p.Kod,'PL'),3) [KodKraju]
		-- 				,case when isnull(kfo.Ulica,'')='' then null else kfo.Ulica end  [Ulica]
		-- 				,case when isnull(kfo.NumerDomu,'')='' then '0' else kfo.NumerDomu end  [NrDomu]
		-- 				,case when isnull(kfo.Miejscowosc,'')='' then (case when isnull(kfo.Poczta,'')='' then null else kfo.Poczta end) else kfo.Miejscowosc end [Miejscowosc]
		-- 				,case when isnull(kfo.KodPocztowy,'')='' or isnull(kfo.Miejscowosc,'')='' then null else kfo.KodPocztowy end [KodPocztowy]
		-- 				FOR XML PATH(''), ROOT('AdresPol'), TYPE
		-- 		 )	
		-- 		from @NaglowekFaktury fk 
		-- 		inner join KontrahenciFirmy kfo on kfo.IDKontrahenta=fk.odbiorca
		-- 		left join Panstwa p with(nolock) on p.IDPanstwa=kfo.PanstwaID
		-- 		where kfo.IDKontrahenta is not null
		-- 		FOR XML PATH(''), ROOT('Adres'), TYPE
		--  )
		-- ,case when isnull(kfo.AdresEMail,'')='' then null else kfo.AdresEMail end [Email]
		-- ,case when isnull(kfo.Telefon,'')='' then null else kfo.Telefon end [Telefon]
		-- ,case when isnull(kfo.IndeksZewnetrzny,'')='' then null else kfo.IndeksZewnetrzny end [NrKlienta]
		-- ,'4' as [Rola]
		-- -- , ( 
		-- --   select 
		-- --   '1' as [RolaInna]
		-- --   ,'Odbiorca' as [OpisRoli]
		-- --   FOR XML PATH(''), ROOT('Rola'), TYPE
		-- -- )
		-- from @NaglowekFaktury nds1
		-- left join [dbo].[DajNipKontrahenta](default,default) nip on nip.IDKontrahenta=nds1.Odbiorca
		-- left join KontrahenciFirmy kfo on kfo.IDKontrahenta=nip.IDKontrahenta --.Kontrahent	
		-- where nds1.Odbiorca is not null and isnull(nds1.Odbiorca,'')<>isnull(nds1.Kontrahent,'')
		--  --left join KontrahenciFirmy kf on kf.IDKontrahenta=nds.Kontrahent
		-- FOR XML PATH(''), ROOT('Podmiot3'), TYPE
		-- )
		,(
			SELECT
				'PLN' [KodWaluty]
				,convert(varchar(10),convert(date,nds.DataDokumentu,121)) [P_1]
				,f.MiejsceFaktur [P_1M]
				,rtrim(nds.NumerPelny) [P_2]
				,convert(varchar(10),convert(date,nds.DataSprzedazy,121)) [P_6]
				,(select netto [P_13_1],vat [P_14_1] from @totalizer where IDDokumentu=@ID and Typ=1 and (StawkaVAT=23.00 or StawkaVAT=22.00) FOR XML PATH(''), TYPE)				
				,(select netto [P_13_2],vat [P_14_2] from @totalizer where IDDokumentu=@ID and Typ=1 and (StawkaVAT=8.00 or StawkaVAT=7.00) FOR XML PATH(''), TYPE)
				,(select netto [P_13_3],vat [P_14_3] from @totalizer where IDDokumentu=@ID and Typ=1 and StawkaVAT=5.00 FOR XML PATH(''), TYPE)
				,(select netto [P_13_4],vat [P_14_4] from @totalizer where IDDokumentu=@ID and Typ=1 and StawkaVAT=-1.00 FOR XML PATH(''), TYPE)
				--,(select netto [P_13_5],vat [P_14_5] from @totalizer where IDDokumentu=@ID and Typ=1 and SymbVat='X' FOR XML PATH(''), TYPE)
				,(select brutto [P_15] from @totalizer where IDDokumentu=@ID and Typ=1 and SymbVat='X'  FOR XML PATH(''), TYPE)
				,( -- Adnotacje
					select
						 @CzyMetodaKasowa [P_16]
						,2 [P_17] --samofakturowanie (1)
						,2 [P_18] --odwrotne obci¹¿enie (1)
						,2 [P_18A] --convert(int,case when t.brutto>15000 then 1 else 2 end)  --mechanizm podzielonej p³atnoœci(1)
						,2 [P_19]
						,2 [P_22]
						,2 [P_23]
						,convert(int,case when nds.CzyFakturaVatMarza=1 then 1 else 2 end) [P_PMarzy]
						, (select top 1 
							 case when vo.id=1 then 1 else null end [P_PMarzy_2]
							,case when vo.id=2 then 1 else null end [P_PMarzy_3_1]
							,case when vo.id=3 then 1 else null end [P_PMarzy_3_2]
							,case when vo.id=4 then 1 else null end [P_PMarzy_3_3]
							from NaglowkiDokumentowSprzedazyOpisyStale op with(nolock)
							join V_FakturaMarzaOpisy vo on vo.tresc=op.opis  
							where op.DokumentuID=@ID
							FOR XML PATH(''), TYPE
							) 
						from @NaglowekFaktury nds 
						join @totalizer t on t.IDDokumentu=nds.IDDokumentu and t.typ=1 and t.SymbVat='X'
						FOR XML PATH('Adnotacje'), TYPE
				   )
				,[RodzajFaktury] = 
					case 
						when @DokumentRozliczeniowy>0 then 'ROZ'
						when nds.TypDokumentu='F.vat' and nds.CzyFakturaZaliczkowa=0 then 'VAT'
						when nds.TypDokumentu='F.vat' and nds.CzyFakturaZaliczkowa=1 then 'ZAL'
						when nds.TypDokumentu='F.vat' and nds.CzyFakturaUproszczona=1 then 'UPR'
						when nds.TypDokumentu='KOREK' and nds.CzyFakturaZaliczkowa=0  then 'KOR'
						when nds.TypDokumentu='KOREK' and nds.CzyFakturaZaliczkowa=1  then 'KOR_ZAL'
						else 'VAT'
					end
				,case when nds.TypDokumentu='KOREK' 
					then (
						select 
							case when ltrim(rtrim(isnull(nds.Opis,'')))=''then 'Korekta dokumentu' else ltrim(rtrim(nds.Opis)) end [PrzyczynaKorekty]
							,1 [TypKorekty]
							, (
								select	
									  convert(date,kor.DataDokumentu,127) [DataWystFaKorygowanej]
									, ltrim(rtrim(kor.NumerPelny)) [NrFaKorygowanej]
									, [NrKSeFFaKorygowanej] = 
										case when isnull(ex.ksefReferenceNumber,'') != '' 
										then ex.ksefReferenceNumber
										else '' 
										end
								from @NaglowekFakturyKorygowanej kor
								left join [dbo].GetExchangedDocument(kor.IDDokumentu,default) ex on 1=1
								FOR XML PATH('DaneFaKorygowanej'), TYPE
							)
						from @NaglowekFakturyKorygowanej kor
						FOR XML PATH(''), TYPE
						)
					else 
						null
					end
				,case when nds.Opis like '%do transakcji%' then 1 else null end  [FP]
				,case when isnull(nabywca.GrupaJPKTP,0)=0 then null else 1 end [TP]
				,( -- DodatkowyOpis -  w sumie s¹ jedynie do Faktur Vat Mar¿a
					select top 12 op.*
					from (
						select 
						'DocumentId' [Klucz]
						,convert(varchar(20),nds.IDDokumentu) [Wartosc]
						from @NaglowekFaktury nds 
						
						union 

						select 
						o.klucz [Klucz]
						,o.opis [Wartosc]
						from @NaglowekFaktury nds 
						join NaglowkiDokumentowSprzedazyOpisyStale o with(nolock) on o.DokumentuID=nds.IDDokumentu
						
						union

						select 
						'opis' [Klucz]
						,nds.opis [Wartosc]
						from @NaglowekFaktury nds 
					) op
					where op.wartosc<>''
					FOR XML PATH('DodatkowyOpis'), TYPE
				  ) 
				,( -- FA(1) numery faktur zaliczkowych rozliczanych aktualn¹ faktur¹
				 	select 
						 zal.NumerPelny [NrFaZaliczkowej]
					from @NaglowkiZaliczek zal 
					FOR XML PATH(''), TYPE
				  )
				,( -- FaWiersze
					select top 1
						  t.pozycji [LiczbaWierszyFaktury]
						, case when convert(int,t.CzySprzedazWedlugNetto)=1 then t.netto else null end [WartoscWierszyFaktury1]
						, case when convert(int,t.CzySprzedazWedlugNetto)=0 then t.brutto else null end [WartoscWierszyFaktury2]
						, (
							select 
							 lds.nr_poz_dok [NrWierszaFa]
							,lds.nazwa [P_7]
							,case when isnull(lds.sww,'')<>'' then lds.sww else null end [PKWiU]
							,case when isnull(lds.OpisPozycji,'')='' then null else lds.OpisPozycji end [DodatkoweInfo]
							,lds.jm [P_8A]
							,abs(lds.Ilosc) [P_8B]
							,case when lds.CzySprzedazWedlugNetto=1 then lds.XCenaN else null end [P_9A]
							,case when lds.CzySprzedazWedlugNetto=0 then lds.XCenaB else null end [P_9B]
							,case when lds.CzySprzedazWedlugNetto=1 then lds.XNetto else null end [P_11]
							,case when lds.CzySprzedazWedlugNetto=0 then lds.XBrutto else null end [P_11A]
							,case when lds.StawkaVAT=-1 then 'zw' else convert(int,lds.StawkaVAT) end [P_12]
							,case when lds.nazwa is null then null else 7 end [P_12_Procedura]
							,gjpk.GrupaJPK [GTU]
							from @NaglowekFaktury nds 
							join @PozycjeFaktury lds on nds.IDDokumentu=lds.IDDokumentu
							left join Towary t with(nolock,index(PK_Towary)) on t.TowaruID=lds.plu
							left join GrupyJPK gjpk on (gjpk.TowaruID=lds.PLU or gjpk.GrupyID=t.Grupa) --and gjpk.GrupaJPK=@gt
							FOR XML PATH('FaWiersz'), TYPE
						 )
					from @NaglowekFaktury nds --with(nolock) 
					join @totalizer t on t.IDDokumentu=nds.IDDokumentu and t.Typ=0 and t.SymbVat='X'
					where nds.CzyFakturaZaliczkowa=0
					FOR XML PATH(''),ROOT('FaWiersze'), TYPE
				   )
				,( -- Rozliczenie
				 	 select 
							(
							select 
								 convert(decimal(19,2),odliczenie.WartoscDS) [Kwota]
								,'Numer faktury zaliczkowej '+odliczenie.NumerPelny+', Data wystawienia: '+convert(varchar(10),odliczenie.DataSprzedazy,121) [Powod]
							from @NaglowkiZaliczek odliczenie
							FOR XML PATH('Odliczenia'), TYPE
							)
							,round(zal.[wartosc_zaliczek],12,2) [SumaOdliczen]
					 from (
					    select top 1 
							sum(WartoscDS) [wartosc_zaliczek] 
						from @NaglowkiZaliczek
					 ) as zal
					 FOR XML PATH('Rozliczenie'), TYPE
				   )
				,( -- p³atnoœci
				   select 
				      case 
						when nds.TerminPlatnosci>nds.DataDokumentu 
						then null 
						else '1' 
					  end [Zaplacono]
				     ,case 
						when nds.TerminPlatnosci>nds.DataDokumentu 
						then null
						else CONVERT(varchar(10),isnull(nds.TerminPlatnosci,nds.DataDokumentu),127)
					  end [DataZaplaty]
					 -- terminy p³atnoœci
					 ,(
						select 
							CONVERT(varchar(10),nds.TerminPlatnosci,127) [TerminPlatnosci]
							, fp.Nazwa [TerminPlatnosciOpis]
					 	from @NaglowekFaktury nds 
						left join NaglowkiDokumentowSprzedazyObroty obr with(nolock) on obr.DokumentuID=nds.IDDokumentu
						left join FormyPlatnosci fp with(nolock) on fp.IDFormyPlatnosci=obr.FormyPlatnosciID
						FOR XML PATH('TerminyPlatnosci'), TYPE
					 )
				     ,case 
						when nds.FormaPlatnosci = 1 then 1 -- 1 gotówka
						when nds.FormaPlatnosci = 2 or fp.Rodzaj=2 then 6 -- 6 przelew
						when nds.FormaPlatnosci = 3 then 2 -- 2 karta    
						else 1
					  end [FormaPlatnosci]
					, (
						case when fi.Konto is not null 
						then (
							select
								replace(replace(fi.Konto,' ',''),'-','') [NrRBPL]
								,[NazwaBanku] = (
									select top 1 NazwaBanku from RachunkiBankowe rb with(nolock) where replace(replace(rb.NumerRachunku,' ',''),'-','')=fi.Konto
								)
							FOR XML PATH('RachunekBankowy'), TYPE
						    ) 
						else 
							null 
						end
					)
				   from @NaglowekFaktury nds 
				   left join FormyPlatnosci fp with(nolock) on fp.IDFormyPlatnosci=nds.FormaPlatnosci
				   left join @firma fi on 1=1 and fp.Rodzaj=2
				   FOR XML PATH(''),ROOT('Platnosc'), TYPE
				 )
				 -- zaliczka - zamówienie
				 ,(
				    select 
						  t.pozycji [LiczbaWierszyZamowienia]
						, t.brutto [WartoscZamowienia]
				 		, (	select 
								  lds.nr_poz_dok [NrWierszaZam]
								, lds.nazwa [P_7Z]
								, lds.jm [P_8AZ]
								, abs(lds.ilosc) [P_8BZ]
								, lds.XCenaN [P_9AZ]
								, lds.XNetto [P_11NettoZ]
								, lds.XVat [P_11VatZ]
								, case when lds.StawkaVAT=-1 then 'zw' else convert(int,lds.StawkaVAT) end [P_12Z] -->8</P_12Z>
							from @NaglowekFaktury nds 
							join @PozycjeFaktury lds on nds.IDDokumentu=lds.IDDokumentu
							left join Towary t with(nolock) on t.TowaruID=lds.plu
							left join GrupyJPK gjpk on (gjpk.TowaruID=lds.PLU or gjpk.GrupyID=t.Grupa) --and gjpk.GrupaJPK=@gt
							FOR XML PATH('ZamowienieWiersz'), TYPE
						 )
					from @NaglowekFaktury nds 
					join @totalizer t on t.IDDokumentu=nds.IDDokumentu and t.Typ=0 and t.SymbVat='X'
					left join @NaglowekFakturyKorygowanej kor on kor.IDDokumentu=nds.KorektaDoDokumentuID
					--left join NaglowkiDokumentowSprzedazy kor with(nolock) on kor.IDDokumentu=nds.KorektaDoDokumentuID
					where nds.CzyFakturaZaliczkowa=1 or kor.CzyFakturaZaliczkowa=1
					FOR XML PATH(''),ROOT('Zamowienie'), TYPE
				)
			from @NaglowekFaktury nds 
			join kasy k with(nolock) on k.IDKasy=nds.KasyID 
			join @firma f on 1=1
			left join KontrahenciFirmy nabywca on nabywca.IDKontrahenta=isnull(nds.odbiorca,nds.Kontrahent)
			FOR XML PATH(''), ROOT('Fa'), TYPE
		)
		,(
			select
				(
					select st.* from (
					    select case when isnull(f.StopkaFaktury,'')='' then null else f.StopkaFaktury end [StopkaFaktury]  union all
					    select case when isnull(f.StalyDopisekDoFaktury,'')='' then null else f.StalyDopisekDoFaktury end [StopkaFaktury]  
					) st FOR XML PATH(''), ROOT('Informacje'), TYPE
				)
				,(
					select 
						--'0000099999' [KRS]
						case when isnull(f.REGON,'')='' then null else f.REGON end [REGON]
						,f.BDO [BDO]
					FOR XML PATH(''), ROOT('Rejestry'), TYPE
				)
			from @firma f
			FOR XML PATH(''), ROOT('Stopka'), TYPE
		)
		FOR XML PATH('') --, ROOT('Faktura') odremowaæ root i scheme przed selectem g³ónym
	)
end

if (@kodSystemowy=2) begin
	select @cRequest = 
	(
	   select
		(
			SELECT top 1
				"KodFormularza/@kodSystemowy"='FA ('+str(@kodSystemowy,1)+')',
				"KodFormularza/@wersjaSchemy"=@wersjaSchemy,
				'FA' [KodFormularza],
				@kodSystemowy AS WariantFormularza,
				CONVERT(varchar,nds.DataDokumentu,127) [DataWytworzeniaFa],
				'GastroKlasyka'+@application AS SystemInfo
			from @NaglowekFaktury nds 
			FOR XML PATH(''), ROOT('Naglowek'), TYPE
		)
		,( -- Podmiot1
			SELECT 
				 [PrefiksPodatnika] = null
				,[NrEORI] = null
				,( -- DaneIdentyfikacyjne
					SELECT
						 [NIP] = f.Nip
						,[Nazwa] = 
							ltrim(rtrim(isnull(f.Nazwa1,'')))
							+(case when isnull(f.Nazwa2,'')='' then '' else ' '+ltrim(rtrim(f.Nazwa2)) end)
							+(case when isnull(f.Nazwa3,'')='' then '' else ' '+ltrim(rtrim(f.Nazwa3)) end)
					FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
				  )
				,( -- Adres
					SELECT							
						 [KodKraju] = f.KodKraju 
						,[AdresL1] = f.Ulica + f.NrDomu 
						,[AdresL2] = f.KodPocztowy+' '+f.Miejscowosc 
					FOR XML PATH(''), ROOT('Adres'), TYPE
				 )
				,[AdresKoresp] = null
				,( -- DaneKontaktowa
					select 
						 [Email] = case when isnull(f.email,'')='' then null else f.email end 
						,[Telefon] = case when isnull(f.Telefon,'')='' then null else f.Telefon end 
					FOR XML PATH(''), ROOT('DaneKontaktowe'), TYPE
				 )
				,[StatusInfoPodatnika] = null
				from @firma f			
			FOR XML PATH(''), ROOT('Podmiot1'), TYPE
		 )
		,( -- Podmiot2
			SELECT 
				 ( -- DaneIdentyfikacyjne
					SELECT
						[NIP] = 
							case
								when isnull(nip.Ustawiono,0)=0 then null
								when (nip.Ustawiono&2)=2 then nip.KartotekaUnijny
								when (nip.Ustawiono&1)=1 then nip.KartotekaPolski
								else isnull(nip.Szukany,nip.KartotekaPolski) 
							end
						,[KodUE] = null
						,[NrVatUE] = null
						,[KodKraju] = null -- jesli nip zagraniczny, mo¿na uzupe³niæ
						,[NrID]=null -- jesli nip zagraniczny, mo¿na uzupe³niæ
						,[BrakID] = case when nip.Ustawiono=0 then 1 else null end											
						,[Nazwa] = isnull(kf.Nazwa1,'')+(case when isnull(kf.Nazwa2,'')='' then '' else ' '+kf.Nazwa2 end) 	
					FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
				  )
				,( -- Adres
					SELECT
						 [KodKraju] = left(isnull(p.Kod,'PL'),3) 
						,[AdresL1] = kf.Nazwa1+rtrim(' '+kf.[Nazwa2] )
						,[AdresL2] = 
							case 
						    	when (isnull(kf.KodPocztowy,'')+isnull(kf.Miejscowosc,''))='' 
						    	then (case when isnull(kf.Poczta,'')='' then null else kf.Poczta end) 
								else (isnull(kf.KodPocztowy,'')+' '+isnull(kf.Miejscowosc,'')) 
								+rtrim(' '+isnull(kf.Ulica,''))
								+rtrim(' '+isnull(kf.NumerDomu,''))
								+(case when isnull(kf.NumerMieszkania,'')<>'' then +'/'+rtrim(kf.NumerMieszkania) else '' end)
							end 								
					from @NaglowekFaktury fk 
					left join KontrahenciFirmy kf on kf.IDKontrahenta=fk.Kontrahent -- isnull(case when ltrim(rtrim(isnull(fk.odbiorca,'')))='' then null else fk.odbiorca end,fk.Kontrahent)
					left join Panstwa p with(nolock) on p.IDPanstwa=kf.PanstwaID
					where kf.IDKontrahenta is not null
					FOR XML PATH(''), ROOT('Adres'), TYPE
				  )
				,[AdresKoresp] = null
				,( -- DaneKontaktowa
					select 
						 [Email] = case when isnull(kf.AdresEMail,'')='' then null else kf.AdresEMail end 
						,[Telefon] = case when isnull(kf.Telefon,'')='' then null else kf.Telefon end 
					FOR XML PATH(''), ROOT('DaneKontaktowe'), TYPE
				 )
				,[NrKlienta] = case when isnull(kf.IndeksZewnetrzny,'')='' then null else kf.IndeksZewnetrzny end
				from @NaglowekFaktury nds1
				left join [dbo].[DajNipKontrahenta](default,default) nip on nip.IDKontrahenta=nds1.Kontrahent
				left join KontrahenciFirmy kf on kf.IDKontrahenta=nip.IDKontrahenta --.Kontrahent	
			FOR XML PATH(''), ROOT('Podmiot2'), TYPE
		 )
		,( -- Podmiot3
			SELECT 
				 [IDNabywcy] = null
				,[NrEORI] = null
				,( -- DaneIdentyfikacyjne
					SELECT
					 [NIP] = kfo.NumerIdentyfikacyjny 
					,[IDWew] = null
					,[KodUE] = null
					,[NrVatUE] = null
					,[KodKraju] = null
					,[NrID] = null
					,[BrakID] = case when nip.Ustawiono=0 then 1 else null end
					,[Nazwa] = case 
									when isnull(nip.Ustawiono,0)=0 then kfo.Nazwa1 
									else isnull(kfo.Nazwa1,'')+(case when isnull(kfo.Nazwa2,'')='' then '' else ' '+kfo.Nazwa2 end) 
								end											
					FOR XML PATH(''), ROOT('DaneIdentyfikacyjne'), TYPE
			     )
			    ,( --Adres
			   		select 
						 [KodKraju] = left(isnull(p.Kod,'PL'),3) 
						,[AdresL1] = kfo.Nazwa1+kfo.[Nazwa2] 
						,[AdresL2] = rtrim(kfo.KodPocztowy)
							+(' '+kfo.Poczta)
							+rtrim(' '+isnull(kfo.Ulica,''))
							+rtrim(' '+isnull(kfo.NumerDomu,''))
							+(case when isnull(kfo.NumerMieszkania,'')<>'' then +'/'+rtrim(kfo.NumerMieszkania) else '' end)
					FOR XML PATH(''), ROOT('Adres'), TYPE
			     )
				,[AdresKoresp] = null
				,( -- DaneKontaktowa
					select 
						 [Email] = case when isnull(kfo.AdresEMail,'')='' then null else kfo.AdresEMail end 
						,[Telefon] = case when isnull(kfo.Telefon,'')='' then null else kfo.Telefon end 
					FOR XML PATH(''), ROOT('DaneKontaktowe'), TYPE
				 )				
				,[Rola] = '4'
				,[Udzial] = null
				,[NrKlienta] = case when isnull(kfo.IndeksZewnetrzny,'')='' then null else kfo.IndeksZewnetrzny end 
			from @NaglowekFaktury nds1
			left join [dbo].[DajNipKontrahenta](default,default) nip on nip.IDKontrahenta=nds1.Kontrahent --.Odbiorca
			left join KontrahenciFirmy kfo on kfo.IDKontrahenta=case when isnull(nds1.Odbiorca,'')='' then nip.IDKontrahenta else nds1.Odbiorca end --.Kontrahent	
			left join Panstwa p with(nolock) on p.IDPanstwa=kfo.PanstwaID
			where isnull(nds1.Odbiorca,'')!=''
			  and isnull(nds1.Odbiorca,'')<>isnull(nds1.Kontrahent,'')
			FOR XML PATH(''), ROOT('Podmiot3'), TYPE
		 )
		,(
			SELECT
				'PLN' [KodWaluty]
				,convert(varchar(10),convert(date,nds.DataDokumentu,121)) [P_1]
				,f.MiejsceFaktur [P_1M]
				,rtrim(nds.NumerPelny) [P_2]
				,convert(varchar(10),convert(date,nds.DataSprzedazy,121)) [P_6]
				,(select netto [P_13_1],vat [P_14_1] from @totalizer where IDDokumentu=@ID and Typ=1 and (StawkaVAT=23.00 or StawkaVAT=22.00) FOR XML PATH(''), TYPE)				
				,(select netto [P_13_2],vat [P_14_2] from @totalizer where IDDokumentu=@ID and Typ=1 and (StawkaVAT=8.00 or StawkaVAT=7.00) FOR XML PATH(''), TYPE)
				,(select netto [P_13_3],vat [P_14_3] from @totalizer where IDDokumentu=@ID and Typ=1 and StawkaVAT=5.00 FOR XML PATH(''), TYPE)
				,(select netto [P_13_4],vat [P_14_4] from @totalizer where IDDokumentu=@ID and Typ=1 and StawkaVAT=-1.00 FOR XML PATH(''), TYPE)
				,(select brutto [P_15] from @totalizer where IDDokumentu=@ID and Typ=1 and SymbVat='X'  FOR XML PATH(''), TYPE)
				, (
					select
						 @CzyMetodaKasowa [P_16]
						,2 [P_17] --samofakturowanie (1)
						,2 [P_18] --odwrotne obci¹¿enie (1)
						,2 [P_18A] --convert(int,case when t.brutto>15000 then 1 else 2 end)  --mechanizm podzielonej p³atnoœci(1)
						,[Zwolnienie] = (
							select 
								[P_19N] = 1
							FOR XML PATH(''), TYPE
						 )
						,[NoweSrodkiTransportu] = (
							select 
								[P_22N] = 1
							for xml path(''), TYPE
						 )
						,2 [P_23]
						,[PMarzy] = (
							select 
							 [P_PMarzy] = convert(int,case when nds.CzyFakturaVatMarza=1 then 1 else null end) 
							,[P_PMarzyN] = convert(int,case when nds.CzyFakturaVatMarza=1 then null else 1 end)
							,(
								select top 1 
									case when vo.id=1 then 1 else null end [P_PMarzy_2]
									,case when vo.id=2 then 1 else null end [P_PMarzy_3_1]
									,case when vo.id=3 then 1 else null end [P_PMarzy_3_2]
									,case when vo.id=4 then 1 else null end [P_PMarzy_3_3]
								from NaglowkiDokumentowSprzedazyOpisyStale op with(nolock)
								join V_FakturaMarzaOpisy vo on vo.tresc=op.opis  
								where op.DokumentuID=@ID
								FOR XML PATH(''), TYPE
							 )
							 FOR XML PATH(''), TYPE
						 ) 
					from @NaglowekFaktury nds 
					join @totalizer t on t.IDDokumentu=nds.IDDokumentu and t.typ=1 and t.SymbVat='X'
					FOR XML PATH('Adnotacje'), TYPE
				)
				,case 
					when @DokumentRozliczeniowy>0 then 'ROZ'
					when nds.TypDokumentu='F.vat' and nds.CzyFakturaZaliczkowa=0 then 'VAT'
					when nds.TypDokumentu='F.vat' and nds.CzyFakturaZaliczkowa=1 then 'ZAL'
					when nds.TypDokumentu='F.vat' and nds.CzyFakturaUproszczona=1 then 'UPR'
					when nds.TypDokumentu='KOREK' and nds.CzyFakturaZaliczkowa=0  then 'KOR'
					when nds.TypDokumentu='KOREK' and nds.CzyFakturaZaliczkowa=1  then 'KOR_ZAL'
					else 'VAT'
				  end [RodzajFaktury]
				, case when nds.TypDokumentu='KOREK' 
					then (
						select 
							 [PrzyczynaKorekty] = case when ltrim(rtrim(isnull(nds.Opis,'')))=''then 'Korekta dokumentu' else ltrim(rtrim(nds.Opis)) end 
							,[TypKorekty] = null
							,[DaneFaKorygowanej] = (
								select	
									 [DataWystFaKorygowanej] = convert(date,kor.DataDokumentu,127) 
									,[NrFaKorygowanej] =ltrim(rtrim(kor.NumerPelny)) 
									,[NrKSeF] = 1
									,[NrKSeFFaKorygowanej] = 
										case when isnull(ex.ksefReferenceNumber,'') != '' 
										then ex.ksefReferenceNumber
										else '' 
										end
								from @NaglowekFakturyKorygowanej kor
								left join [dbo].GetExchangedDocument(kor.IDDokumentu,default) ex on 1=1
								FOR XML PATH(''), TYPE
							 )
							,[OkresFaKorygowanej] = null
							,[NrFaKorygowany] = null
							,[Podmiot1K] = null -- zmiana danych sprzedawcy
							,[Podmiot2K] = null -- korekta danych Podmiotu2
							,[P_15ZK] = null -- kwota faktury zaliczkowej przed korekt¹
							,[KursWalutyZK] = null 
						from @NaglowekFakturyKorygowanej kor
						FOR XML PATH(''), TYPE
						)
					else 
						null
					end
				,[FP] = case when nds.Opis like '%do transakcji%' then 1 else null end
				,[TP] = case when isnull(nabywca.GrupaJPKTP,0)=0 then null else 1 end 
				,( -- DodatkowyOpis -  w sumie s¹ jedynie do Faktur Vat Mar¿a
					select top 12 op.*
					from (
						select 
						'DocumentId' [Klucz]
						,convert(varchar(20),nds.IDDokumentu) [Wartosc]
						from @NaglowekFaktury nds 
						
						union 

						select 
						o.klucz [Klucz]
						,o.opis [Wartosc]
						from @NaglowekFaktury nds 
						join NaglowkiDokumentowSprzedazyOpisyStale o with(nolock) on o.DokumentuID=nds.IDDokumentu
						
						union

						select 
						'opis' [Klucz]
						,nds.opis [Wartosc]
						from @NaglowekFaktury nds 

					) op
					where op.wartosc<>''
					FOR XML PATH('DodatkowyOpis'), TYPE
				 ) 
				,( -- FakturaZaliczkowa --zaliczki s¹ opakowane i prezentuj¹ numery ksef
				 	select 
						(
							select 
								[NrKSeFZN] = null --znacznik faktury spoza ksef
								,[NrFaZaliczkowej] = zal.NumerPelny -- Numer faktury zaliczkowej wystawionej poza KSeF...
							where isnull(ex.ksefReferenceNumber,'')=''
							FOR XML PATH(''), TYPE		
						)
						,[NrKSeFFaZaliczkowej] = ex.ksefReferenceNumber
					from @NaglowkiZaliczek zal 
					cross apply [dbo].GetExchangedDocument(zal.IDDokumentu,default) ex
					FOR XML PATH('FakturaZaliczkowa'), TYPE
				  )
				,[ZwrotAkcyzy] = null
				,( -- FaWiersz
					select 
					 [NrWierszaFa] = lds.nr_poz_dok 
					,[UU_ID] = null --lds.pozycja
					,[P_6A] = null
					,[P_7] = lds.nazwa
					,[Indeks] = lds.plu
					,[GTIN] = null
					,[PKWiU] = case when isnull(lds.sww,'')<>'' then lds.sww else null end 
					,[CN] = null
					,[PKOB] = null
					,[P_8A] = lds.jm
					,[P_8B] = abs(lds.Ilosc)
					,[P_9A] = case when lds.CzySprzedazWedlugNetto=1 then lds.XCenaN else null end 
					,[P_9B] = case when lds.CzySprzedazWedlugNetto=0 then lds.XCenaB else null end 
					,[P_10] = null
						-- case 
						-- 	when @x_czy_info_rabat_fv=1 and lds.cena_nomin<>lds.cena 
						-- 	then str(round(lds.cena_nomin*lds.ilosc,2)- round(lds.cena*lds.ilosc,2),12,2)
						-- 	else null 
						-- end --kwoty upustów
					,[P_11] = case when lds.CzySprzedazWedlugNetto=1 then lds.XNetto else null end 
					,[P_11A] = case when lds.CzySprzedazWedlugNetto=0 then lds.XBrutto else null end 
					,[P_11AVat] = null
					,[P_12] = case when lds.StawkaVAT=-1 then 'zw' else convert(int,lds.StawkaVAT) end 
					,[P_12_XII] = null
					,[P_12_Zal_15] = null
					,[KwotaAkcyzy] = null
					,[GTU] = gjpk.GrupaJPK
					,[Procedura] = null --case when lds.nazwa is null then null else 7 end 
					,[KursWaluty] = null
					,[StanPrzed] = null
					from @NaglowekFaktury nds 
					join @PozycjeFaktury lds on nds.IDDokumentu=lds.IDDokumentu
					left join Towary t with(nolock,index(PK_Towary)) on t.TowaruID=lds.plu
					outer apply (
						select top 1 GrupaJPK 
						from GrupyJPK gjpk with(nolock)
						where (gjpk.TowaruID=lds.PLU or gjpk.GrupyID=t.Grupa) 
						and gjpk.GrupaJPK!=''
					) gjpk
					FOR XML PATH('FaWiersz'), TYPE
				 )
				,( -- Rozliczenie
				 	select 
						( -- Odliczenia
							select 
								 [Kwota] = convert(decimal(19,2),odliczenie.WartoscDS) 
								,[Powod] = 'Numer faktury zaliczkowej '+odliczenie.NumerPelny+', Data wystawienia: '+convert(varchar(10),odliczenie.DataSprzedazy,121) 
							from @NaglowkiZaliczek odliczenie
							FOR XML PATH('Odliczenia'), TYPE
						 )
						,[SumaOdliczen] = ltrim(str(zal.wartosc_zaliczek,12,2))
					 from (
					    select top 1 
							ltrim(str(sum(WartoscDS),12,2)) [wartosc_zaliczek] 
						from @NaglowkiZaliczek
					 ) as zal
					 FOR XML PATH('Rozliczenie'), TYPE
				   )
				,( -- Platnosc
				   select 
				     [Zaplacono] =
					 	case 
							when nds.TerminPlatnosci>nds.DataDokumentu 
							then null 
							else '1' 
					  	end 
				    ,[DataZaplaty] = 
					 	case 
							when nds.TerminPlatnosci>nds.DataDokumentu 
							then null
							else CONVERT(varchar(10),isnull(nds.TerminPlatnosci,nds.DataDokumentu),127)
					  	end 
					,[ZnacznikZaplatyCzesciowej] = null
					,[ZaplataCzesciowa] = null
					,( -- terminy p³atnoœci
						select 
							 [Termin] = CONVERT(varchar(10),nds.TerminPlatnosci,127) 
							,[TerminOpis] = fp.Nazwa 
					 	from @NaglowekFaktury nds 
						left join NaglowkiDokumentowSprzedazyObroty obr with(nolock) on obr.DokumentuID=nds.IDDokumentu
						left join FormyPlatnosci fp with(nolock) on fp.IDFormyPlatnosci=obr.FormyPlatnosciID
						FOR XML PATH('TerminPlatnosci'), TYPE
					  )
				    ,[FormaPlatnosci] = 
					 	case 
							when nds.FormaPlatnosci = 1 then 1 -- 1 documentation gotówka
							when nds.FormaPlatnosci = 2 /*or fp.Rodzaj=2*/ then 6 -- 6 documentation przelew
							when nds.FormaPlatnosci = 3 then 2 -- 2 documentation karta    
							else null
					  	end 
					,[PlatnoscInna] = 
						case 
							when nds.FormaPlatnosci not in (1,2,3)
							then 1
							else null
						end
					,[OpisPlatnosci] = 
						case 
							when nds.FormaPlatnosci not in (1,2,3)
							then fp.Nazwa
							else null
						end					

					,( -- RachunekBankowy
						case when rtrim(isnull(fi.Konto,''))<>''
						then (
							select
								 [NrRB] = replace(replace(fi.Konto,' ',''),'-','')
								,[SWIFT] = null
								,[RachunekWlasnyBanku] = null
								,[NazwaBanku] = (
									select top 1 NazwaBanku 
									from RachunkiBankowe rb with(nolock) 
									where replace(replace(rb.NumerRachunku,' ',''),'-','')=fi.Konto
								 )
								,[OpisRachunku] = null
							FOR XML PATH('RachunekBankowy'), TYPE
						    ) 
						else 
							null 
						end
					  )
				   from @NaglowekFaktury nds 
				   left join FormyPlatnosci fp with(nolock) on fp.IDFormyPlatnosci=nds.FormaPlatnosci
				   left join @firma fi on 1=1 and fp.Rodzaj=2
				   FOR XML PATH(''),ROOT('Platnosc'), TYPE
				  )
				,[WarunkiTransakcji] = null
				,( -- Zamowienie - zaliczka
				    select 
						 -- t.pozycji [LiczbaWierszyZamowienia]
						 [WartoscZamowienia] = t.brutto
				 		,(	select 
								 [NrWierszaZam] = lds.nr_poz_dok 
								,[UU_IDZ] = null
								,[P_7Z] = lds.nazwa 
								,[IndeksZ] = null
								,[GTINZ] = null
								,[PKWiUZ] = null
								,[CNZ] = null
								,[PKOBZ] = null
								,[P_8AZ] = lds.jm 
								,[P_8BZ] = abs(lds.ilosc)
								,[P_9AZ] = lds.XCenaN
								,[P_11NettoZ] = lds.XNetto
								,[P_11VatZ] = lds.XVat
								,[P_12Z] = case when lds.StawkaVAT=-1 then 'zw' else convert(int,lds.StawkaVAT) end
								,[P_12Z_XII] = null
								,[P_12Z_Zal_15] = null
								,[GTUZ] = null
								,[ProceduraZ] = null
								,[KwotaAkcyzyZ] = null
								,[StanPrzedZ] = null
							from @NaglowekFaktury nds 
							join @PozycjeFaktury lds on nds.IDDokumentu=lds.IDDokumentu
							left join Towary t with(nolock) on t.TowaruID=lds.plu
							left join GrupyJPK gjpk on (gjpk.TowaruID=lds.PLU or gjpk.GrupyID=t.Grupa) --and gjpk.GrupaJPK=@gt
							FOR XML PATH('ZamowienieWiersz'), TYPE
						 )
					from @NaglowekFaktury nds 
					join @totalizer t on t.IDDokumentu=nds.IDDokumentu and t.Typ=0 and t.SymbVat='X'
					left join @NaglowekFakturyKorygowanej kor on kor.IDDokumentu=nds.KorektaDoDokumentuID
					where nds.CzyFakturaZaliczkowa=1 or kor.CzyFakturaZaliczkowa=1
					FOR XML PATH(''),ROOT('Zamowienie'), TYPE
				  )
			from @NaglowekFaktury nds 
			join kasy k with(nolock) on k.IDKasy=nds.KasyID 
			join @firma f on 1=1 --f.ID=k.Firma
			left join KontrahenciFirmy nabywca on nabywca.IDKontrahenta=isnull(nds.odbiorca,nds.Kontrahent)
			FOR XML PATH(''), ROOT('Fa'), TYPE
		)
		,[Stopka] = (
			select
				 [Informacje] = (
					select st.* from (
					    select case when isnull(f.StopkaFaktury,'')='' then null else f.StopkaFaktury end [StopkaFaktury]  union all
					    select case when isnull(f.StalyDopisekDoFaktury,'')='' then null else f.StalyDopisekDoFaktury end [StopkaFaktury]  
					) st 
					FOR XML PATH(''), TYPE
				  )
				,[Rejestry] = (
					select 
						 [REGON] = case when isnull(f.REGON,'')='' then null else f.REGON end 
						,[BDO] = f.BDO
					FOR XML PATH(''), TYPE
				)
			from @firma f
			FOR XML PATH(''), TYPE
		)
		FOR XML PATH('') --, ROOT('Faktura') odremowaæ root i scheme przed selectem g³ównym
	)
end

declare @edt varchar(150)='http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2021/06/09/eD/DefinicjeTypy/'
declare @targetNamespace varchar(150)='http://crd.gov.pl/wzor/2021/11/29/11089/'
if (@kodSystemowy=2) begin
	set @edt='http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/'
	set @targetNamespace='http://crd.gov.pl/wzor/2023/06/29/12648/'
end
-- to poni¿ej nie konieczne, jeœli mamy ;WITH ze schem¹ przed selectem
set @cRequest = cast(
    '<Faktura '+
		'xmlns="'+@targetNamespace+'" '+
		'xmlns:edt="'+@edt+'" '+
		'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
		CAST( @cRequest  AS NVARCHAR(MAX))+
    '</Faktura>'
	 as xml)

select @cRequest

end
go
--#endregion [InvoiceKSEF]