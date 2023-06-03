﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function analyse()	
	SetDataFolder root:
	
	assignTypeWherePatternMatches()
	
	// collect amounts for types
	Wave/T Verwendungszweck, Typ
	Wave Betrag
	Make/O/N=0/T GesamtTyp
	Make/O/N=0 GesamtBetrag
	int i
	int nBuchungen = DimSize(Betrag, 0)
	for(i = 0; i < nBuchungen; i += 1)
		int found = 0
		int ityp
		for(ityp = 0; ityp < DimSize(GesamtTyp, 0); ityp += 1)
			if(StringMatch(Typ[i], GesamtTyp[ityp]))
				found = 1
				GesamtBetrag[ityp] += Betrag[i]
			endif
		endfor
		if(found != 1)
			appendTo(Betrag[i], GesamtBetrag)
			appendTo_T(Typ[i], GesamtTyp)
		endif
	endfor	
	
	// assign groups
	Wave/T GesamtGruppe, MapTypGruppe
	int iptr
	for(i = 0; i < DimSize(GesamtTyp, 0); i += 1)
		for(iptr = 0; iptr < DimSize(MapTypGruppe, 0); iptr += 1)
			if(StringMatch(GesamtTyp[i], MapTypGruppe[iptr][0]))
				GesamtGruppe[i] = MapTypGruppe[iptr][1]
				break
			endif
		endfor
	endfor
	
	// relate to month and sort by amount
	Duplicate/O GesamtBetrag, GesamtBetragProMonat
	GesamtBetragProMonat /= 12
	GesamtBetragProMonat = (round(GesamtBetragProMonat*100))/100
	SORT GesamtBetrag, GesamtBetrag, GesamtBetragProMonat, GesamtTyp, GesamtGruppe
	
	// look where anything is left
	Make/O/N=0/T Unkateg_Name_Zahlungsbeteiligter, Unkateg_Verwendungszweck
	Make/O/N=0 Unkateg_Betrag
	WAVE/T Name_Zahlungsbeteiligter	
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
		found = 0
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
Function assignTypeWherePatternMatches()
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
function showGroups()
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