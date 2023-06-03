#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function analyse()
	SetDataFolder root:
	
	assignTypes()
	
	collectAmountsForTypes()
	
	assignGroups()
	
	// relate to month and sort by amount
	Wave/T GesamtTyp, GesamtGruppe
	Wave GesamtBetrag
	Duplicate/O GesamtBetrag, GesamtBetragProMonat
	GesamtBetragProMonat /= 12
	GesamtBetragProMonat = (round(GesamtBetragProMonat*100))/100
	SORT GesamtBetrag, GesamtBetrag, GesamtBetragProMonat, GesamtTyp, GesamtGruppe
	
	// look where anything is left
	Wave/T Verwendungszweck, Typ, Name_Zahlungsbeteiligter
	Wave Betrag
	Make/O/N=0/T Unkateg_Name_Zahlungsbeteiligter, Unkateg_Verwendungszweck
	Make/O/N=0 Unkateg_Betrag
	int i
	int nBuchungen = DimSize(Betrag, 0)	
	for(i = 0; i < nBuchungen; i += 1)
		if(StringMatch("", Typ[i]))
			appendTo_T(Name_Zahlungsbeteiligter[i], Unkateg_Name_Zahlungsbeteiligter)
			appendTo_T(Verwendungszweck[i], Unkateg_Verwendungszweck)
			appendTo(Betrag[i], Unkateg_Betrag)
		endif
	endfor

	// collect amounts for groups
	Make/O/N=0/T Gruppen
	Make/O/N=0 GruppenBetragProMonat
	int total = DimSize(GesamtTyp, 0)
	for(i = 0; i < total; i += 1)
		int found = 0
		int igruppe
		for(igruppe = 0; igruppe < DimSize(Gruppen, 0); igruppe += 1)
			if(StringMatch(GesamtGruppe[i], Gruppen[igruppe]))
				found = 1
				GruppenBetragProMonat[igruppe] += GesamtBetragProMonat[i]
				break
			endif
		endfor
		if(found != 1)
			appendTo(GesamtBetragProMonat[i], GruppenBetragProMonat)
			appendTo_T(GesamtGruppe[i], Gruppen)
		endif
	endfor
	
	// sort amounts of groups
	SORT GruppenBetragProMonat, GruppenBetragProMonat, Gruppen
	
	// expenses are positive
	GesamtBetragProMonat = -GesamtBetragProMonat
	GruppenBetragProMonat = -GruppenBetragProMonat
end
//=================================================================
Function assignTypes()
	WAVE/T Verwendungszweck, Patterns, Typen, Name_Zahlungsbeteiligter
	WAVE Betrag
	SVAR/SDFR=root:config accountOwner
	Duplicate/O/T Verwendungszweck Typ
	Typ = ""
	int iBuchung, iPattern
	int noMatch = 0
	int nBuchungen = DimSize(Betrag, 0)
	int nPatterns = DimSize(Patterns, 0)
	
	for(iBuchung = 0; iBuchung < nBuchungen; iBuchung += 1)
		if(StringMatch(Name_Zahlungsbeteiligter[iBuchung], "*" + accountOwner + "*")) // special logic for transfer without subject
			Typ[iBuchung] = "Sparen/Investment"
			continue
		endif
		for(iPattern = 0; iPattern < nPatterns; iPattern += 1)
			if(StringMatch(Verwendungszweck[iBuchung], Patterns[iPattern]))
				Typ[iBuchung] = Typen[iPattern]
				break
			endif
			if(iPattern == nPatterns - 1) // last pattern checked, nothing found
				noMatch += 1
			endif
		endfor
	endfor
	
	Variable match = nBuchungen - noMatch
	Variable matchPercentage = 100*match/nBuchungen
	print match , "/", nBuchungen, "    (", matchPercentage, "%)"
End
//=================================================================
Function collectAmountsForTypes()
	Wave/T Typ
	Wave Betrag
	Make/O/N=0/T GesamtTyp
	Make/O/N=0 GesamtBetrag
	int iBuchung
	int nBuchungen = DimSize(Betrag, 0)
	
	for(iBuchung = 0; iBuchung < nBuchungen; iBuchung += 1)
		int found = 0
		int iTyp
		for(iTyp = 0; iTyp < DimSize(GesamtTyp, 0); iTyp += 1)
			if(StringMatch(Typ[iBuchung], GesamtTyp[iTyp]))
				found = 1
				GesamtBetrag[iTyp] += Betrag[iBuchung]
			endif
		endfor
		if(found != 1)
			appendTo(Betrag[iBuchung], GesamtBetrag)
			appendTo_T(Typ[iBuchung], GesamtTyp)
		endif
	endfor
End
//=================================================================
Function assignGroups()
	Wave/T GesamtTyp, GesamtGruppe, MapTypGruppe
	int iTyp
	int iPattern
	for(iTyp = 0; iTyp < DimSize(GesamtTyp, 0); iTyp += 1)
		for(iPattern = 0; iPattern < DimSize(MapTypGruppe, 0); iPattern += 1)
			if(StringMatch(GesamtTyp[iTyp], MapTypGruppe[iPattern][0]))
				GesamtGruppe[iTyp] = MapTypGruppe[iPattern][1]
				break
			endif
		endfor
	endfor
End
//=================================================================
Function BarChart()
	wave GruppenBetragProMonat
	wave/T Gruppen
	Display /W=(35.25,41.75,1368,404.75) GruppenBetragProMonat
	ModifyGraph mode=1
	ModifyGraph lSize=10
	ModifyGraph rgb=(2,39321,1)
	ModifyGraph hbFill=2
	SetAxis left 0,*
	int i = 0;
	for(i = 0; i < dimsize(Gruppen,0) - 1; i+=1)
		Tag/C/N=$("text"+num2istr(i))/F=0/A=LC/X=1.00/Y=1.00/L=0 GruppenBetragProMonat, i, Gruppen[i]
	endfor
	ModifyGraph tick=2,nticks(bottom)=10,userticks(bottom)={GruppenBetragProMonat,Gruppen}
	ModifyGraph grid(left)=2,mirror(left)=3,nticks(bottom)=0,minor(left)=1,userticks(bottom)=0
End
//=================================================================
Function showGroups()
	wave/T Gruppen,GesamtTyp,GesamtGruppe
	wave GruppenBetragProMonat,GesamtBetragProMonat
	variable iGruppe, iTyp
		
	// nun Gruppen breakdown
	for(iGruppe = 0; iGruppe < dimsize(Gruppen, 0); iGruppe += 1)
		string thisGroup = Gruppen[iGruppe]
		print thisgroup, "(gesamt ", GruppenBetragProMonat[iGruppe], ")"
		
		for(iTyp=0; iTyp<dimsize(GesamtTyp,0); iTyp+=1)
			if(StringMatch(GesamtGruppe[iTyp], thisGroup))
				print "    ", GesamtTyp[iTyp], "( ", GesamtBetragProMonat[iTyp], ")"
			endif		
		endfor
	endfor
end
//=================================================================
// Append new cell to 1D wave. 
Function appendto(cell,wv)
	Variable cell
	Wave wv
	
	Variable n = numpnts(wv)
	Redimension/N=(n+1) wv
	wv[n] = cell
End
//=================================================================
// Append new cell to 1D text wave.
Function appendto_T(cell,wv)
	String cell
	Wave/T wv
	
	Variable n = numpnts(wv)
	Redimension/N=(n+1) wv
	wv[n] = cell
End