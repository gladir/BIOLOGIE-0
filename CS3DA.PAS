{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/biologie-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal
  @description: Clone de l'application CS3DA (Circulatory System 3D Anatomy)
}

Program CS3DA;

Uses {$IFDEF FPC}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

Const
 AppVersion='1.00';
 {$IFDEF FPC}
  DirSep='/';
 {$ELSE}
  DirSep='\';
 {$ENDIF}

 ScrW=640; ScrH=480;          { Resolution VGA 640x480x16 }
 MenuH=17; StatH=16;          { Barre de menu et barre d'etat }
 InfoW=160; TrH=84;           { Panneau d'information et panneau de trace }
 TrLeft=64; TrWin=4.0;        { Marge gauche et fenetre de trace (secondes) }
 CamDist=350.0;              { Distance de la camera (perspective) }

 MaxV=900; MaxF=1000; MaxS=24; MaxVes=80; MaxPts=500; MaxPart=400;
 MaxItem=1700; MaxView=12; MaxProf=10; MaxMenu=8; MaxMItem=90;

 { Commandes de menu }
 cmQuit=1; cmLoad=2; cmImport=3; cmExpCSV=4; cmExpTXT=5; cmExpOBJ=6;
 cmView=10;                   { 10..17 : vues anatomiques }
 cmCam=20;                    { 20..26 : positions de camera }
 cmOrbit=27; cmZoomIn=28; cmZoomOut=29; cmCamReset=30;
 cmShow=40;                   { 40..49 : affichage des structures }
 cmFlow=60;                   { 60..63 : modes de flux }
 cmOxy=64;                    { 64..66 : modes d'oxygenation }
 cmVes=67;                    { 67..69 : groupes de vaisseaux }
 cmHRUp=70; cmHRDn=71; cmPrUp=72; cmPrDn=73;
 cmProf=80;                   { 80..89 : profils }
 cmPlay=90; cmStop=91; cmLoop=92; cmSpdUp=93; cmSpdDn=94; cmFpsUp=95; cmFpsDn=96;
 cmKeys=100; cmAbout=101;

Type
 TVert=Record X,Y,Z:Real; S:Byte; End;
 TVertArr=Array[1..MaxV] Of TVert;
 PVertArr=^TVertArr;
 TPt=Record X,Y,Z,R,L:Real; V:Integer; End;
 TPtArr=Array[1..MaxPts] Of TPt;
 PPtArr=^TPtArr;
 TScr=Record X,Y,R:Integer; End;
 TScrArr=Array[1..MaxV] Of TScr;
 PScrArr=^TScrArr;
 TScrPtArr=Array[1..MaxPts] Of TScr;
 PScrPtArr=^TScrPtArr;
 TFace=Record S,N:Byte; V:Array[1..4] Of Integer; End;
 TFaceArr=Array[1..MaxF] Of TFace;
 PFaceArr=^TFaceArr;
 TStruct=Record
  Name:String[24]; Kind,Style,Col,Dark:Byte; Beat:Char; CX,CY,CZ:Real;
 End;
 TVessel=Record
  Name:String[26]; VT,Circ:Byte; SatA,SatB:Integer; Lbl:Boolean;
  Vel,Len:Real; First,Cnt,PFirst,PCnt:Integer;
 End;
 TView=Record Name:String[12]; X,Y,Z,Zoom:Real; End;
 TProfile=Record Name:String[14]; HR,Sys,Dia,SV:Integer; Spd:Real; End;
 TMItem=Record Cap:String[26]; Sc:String[8]; Cmd:Integer; End;
 TMenu=Record Title:String[12]; X,W,First,Cnt:Integer; End;

Var
 { ---- Options de la ligne de commande ---- }
 OptQuiet:Boolean;
 ModelFile,ProfName,ExpFile,FmtName,ViewName,CamName:String;
 ImpFiles:Array[1..4] Of String[80];
 NImp:Integer;
 HRGiven,PrGiven,SpdGiven,ZoomGiven:Boolean;
 OptHR,OptPr:Integer; OptSpd,OptZoom:Real;
 ShowListed:Boolean;
 InCfg:Boolean;

 { ---- Journal ---- }
 LogF:Text; LogOn:Boolean;
 GfxOn:Boolean;
 ExeDir:String;

 { ---- Modele 3D ---- }
 Vtx,VCam:PVertArr;
 Vsc:PScrArr;
 Faces:PFaceArr;
 Pts,PCam:PPtArr;
 Psc:PScrPtArr;
 NV,NF,NS,NVes,NPts,NView,NProf:Integer;
 Structs:Array[1..MaxS] Of TStruct;
 Ves:Array[1..MaxVes] Of TVessel;
 Views:Array[1..MaxView] Of TView;
 Profs:Array[1..MaxProf] Of TProfile;
 PartT:Array[1..MaxPart] Of Real;
 NPart:Integer;
 ModelName:String;

 { ---- Physiologie ---- }
 HR,PSys,PDia,SV,EsvBase:Integer;
 SpeedF:Real;
 A0,A1,V0,V1,BeatV,BeatA,Pulsat:Real;
 VelType:Array[0..2] Of Real;
 SatArt,SatVen:Integer;
 EcgTab,PresTab:Array[0..255] Of Integer;

 { ---- Animation ---- }
 Playing,Looping:Boolean;
 Duration,SimT,CycleAcc:Real;
 FPS:Integer;
 PhaseF,KV,KA:Real;
 HeartKey,LastHeartKey:Integer;

 { ---- Affichage ---- }
 ShowArt,ShowVein,ShowCap,ShowHeart,ShowLung,ShowBody:Boolean;
 ShowBlood,ShowLabels,ShowInfo,ShowTrace,ShowSys,ShowPul,GridOn:Boolean;
 FlowMode,OxyMode,BgCol:Integer;
 Sel:Integer;
 StatusMsg:String;

 { ---- Camera ---- }
 Yaw,Pitch,Zoom,TgX,TgY,TgZ,BaseScale:Real;
 OffX,OffY:Integer;
 Orbit:Boolean;
 CamIdx:Integer;
 CurView:String[12];

 { ---- Disposition ---- }
 VX1,VY1,VX2,VY2,VW,VH,InfoX,TrY,TrW:Integer;
 CX0,CY0,OX,OY:Integer;
 HX1,HY1,HX2,HY2,PHX1,PHY1,PHX2,PHY2:Integer;

 { ---- Liste d'affichage ---- }
 ItKind:Array[1..MaxItem] Of Byte;
 ItIdx,ItKey,ItOrd:Array[1..MaxItem] Of Integer;
 NItems:Integer;
 Poly:Array[1..6] Of PointType;
 LblX,LblY:Array[1..60] Of Integer;
 NLbl:Integer;

 { ---- Particules (XOR) ---- }
 OldPX,OldPY,OldPC,OldPH:Array[1..MaxPart] Of Integer;
 NOld:Integer;

 { ---- Trace ---- }
 TrHead:Integer;

 { ---- Menus ---- }
 Menus:Array[1..MaxMenu] Of TMenu;
 MI:Array[1..MaxMItem] Of TMItem;
 NMenu,NMI:Integer;

 { ---- Souris et etat ---- }
 MX,MY,MB:LongInt;
 NeedAll,NeedFull,NeedInfo,Quit:Boolean;
 LastInfo:LongInt;
 MsgLines:Array[1..18] Of String[60];
 MsgN:Integer;

{$IFDEF FPC}
 Type
  PByteBuf=^Byte;
 Var
  CurBuf:PByteBuf; CurSize:LongInt; CurX,CurY:Integer; CurOn:Boolean;
{$ENDIF}

{ ====================================================================
  Souris
  ==================================================================== }

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 { Curseur logiciel : sauvegarde de l'arriere-plan puis dessin d'une fleche }
 Procedure HideMouse;
 Begin
  If CurOn Then Begin
   PutImage(CurX,CurY,CurBuf^,NormalPut);
   CurOn:=False;
  End;
 End;

 Procedure ShowMouse;
 Var
  PX,PY,PB:LongInt;
 Begin
  If Not CurOn Then Begin
   GetMouseState(PX,PY,PB);
   If PX>ScrW-12 Then PX:=ScrW-12;
   If PY>ScrH-16 Then PY:=ScrH-16;
   If PX<0 Then PX:=0;
   If PY<0 Then PY:=0;
   CurX:=PX; CurY:=PY;
   GetImage(CurX,CurY,CurX+11,CurY+15,CurBuf^);
   SetColor(Black);
   Line(CurX,CurY,CurX,CurY+13);
   Line(CurX,CurY,CurX+9,CurY+9);
   Line(CurX,CurY+13,CurX+3,CurY+10);
   Line(CurX+3,CurY+10,CurX+6,CurY+15);
   Line(CurX+6,CurY+15,CurX+8,CurY+14);
   Line(CurX+8,CurY+14,CurX+5,CurY+9);
   Line(CurX+5,CurY+9,CurX+9,CurY+9);
   SetColor(White);
   Line(CurX+1,CurY+3,CurX+1,CurY+11);
   Line(CurX+2,CurY+4,CurX+7,CurY+9);
   Line(CurX+4,CurY+10,CurX+6,CurY+13);
   CurOn:=True;
  End;
 End;
{$ENDIF}

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

{ ====================================================================
  Utilitaires
  ==================================================================== }

Function UpStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 UpStr:=S;
End;

Function TrimStr(S:String):String;
Var
 I,J:Integer;
Begin
 I:=1;
 While (I<=Length(S))And(S[I] In [' ',#9]) Do Inc(I);
 J:=Length(S);
 While (J>=I)And(S[J] In [' ',#9,#13,#10]) Do Dec(J);
 TrimStr:=Copy(S,I,J-I+1);
End;

Function NextTok(Var S:String):String;
Var
 I:Integer;
Begin
 S:=TrimStr(S);
 I:=1;
 While (I<=Length(S))And Not(S[I] In [' ',#9]) Do Inc(I);
 NextTok:=Copy(S,1,I-1);
 Delete(S,1,I-1);
End;

Function StrReal(S:String;Def:Real):Real;
Var
 R:Real;
 C:Integer;
Begin
 Val(TrimStr(S),R,C);
 If C<>0 Then R:=Def;
 StrReal:=R;
End;

Function StrInt(S:String;Def:LongInt):LongInt;
Begin
 StrInt:=Round(StrReal(S,Def));
End;

Function IntStr(L:LongInt):String;
Var
 S:String;
Begin
 Str(L,S);
 IntStr:=S;
End;

Function RealStr(R:Real;D:Integer):String;
Var
 S:String;
Begin
 Str(R:0:D,S);
 RealStr:=S;
End;

Function ClampI(R:Real):Integer;
Begin
 If R>30000.0 Then R:=30000.0 Else
 If R<-30000.0 Then R:=-30000.0;
 ClampI:=Round(R);
End;

Function MaxI(A,B:Integer):Integer;
Begin
 If A>B Then MaxI:=A Else MaxI:=B;
End;

Function MinI(A,B:Integer):Integer;
Begin
 If A<B Then MinI:=A Else MinI:=B;
End;

Function Ticks:LongInt;
Var
 H,M,S,HS:Word;
Begin
 GetTime(H,M,S,HS);
 Ticks:=((LongInt(H)*60+M)*60+S)*100+HS;
End;

Function FileThere(Fn:String):Boolean;
Var
 F:File;
Begin
 Assign(F,Fn);
 {$I-}Reset(F,1);{$I+}
 If IOResult=0 Then Begin
  Close(F);
  FileThere:=True;
 End
  Else
 FileThere:=False;
End;

Function TryFile(Base,Fn:String):String;
Begin
 TryFile:='';
 If FileThere(Base+Fn) Then TryFile:=Base+Fn Else
 If FileThere(Base+UpStr(Fn)) Then TryFile:=Base+UpStr(Fn);
End;

{ Cherche un fichier : tel quel, dans SAMPLES\CS3DA, puis a cote du programme }
Function FindFile(Fn:String):String;
Var
 R:String;
Begin
 FindFile:='';
 If Fn='' Then Exit;
 R:=TryFile('',Fn);
 If R='' Then R:=TryFile('SAMPLES'+DirSep+'CS3DA'+DirSep,Fn);
 If R='' Then R:=TryFile(ExeDir,Fn);
 If R='' Then R:=TryFile(ExeDir+'SAMPLES'+DirSep+'CS3DA'+DirSep,Fn);
 If R='' Then R:=TryFile('..'+DirSep+'SAMPLES'+DirSep+'CS3DA'+DirSep,Fn);
 FindFile:=R;
End;

Procedure LogMsg(S:String);
Begin
 If LogOn Then Begin
  WriteLn(LogF,S);
  Flush(LogF);
 End;
End;

Procedure SetStatus(S:String);
Begin
 StatusMsg:=S;
 LogMsg(S);
End;

{ Message informationnel (supprime par /QUIET) }
Procedure Info(S:String);
Begin
 LogMsg(S);
 If (Not OptQuiet)And(Not GfxOn) Then WriteLn(S);
End;

Procedure Warn(S:String);
Begin
 LogMsg('AVERTISSEMENT: '+S);
 If GfxOn Then StatusMsg:=S Else If Not OptQuiet Then WriteLn('Avertissement : ',S);
End;

Function ColorByName(S:String):Integer;
Const
 Names:Array[0..16] Of String[12]=('BLACK','BLUE','GREEN','CYAN','RED','MAGENTA',
  'BROWN','LIGHTGRAY','DARKGRAY','LIGHTBLUE','LIGHTGREEN','LIGHTCYAN','LIGHTRED',
  'LIGHTMAGENTA','YELLOW','WHITE','GRAY');
Var
 I:Integer;
Begin
 S:=UpStr(S);
 ColorByName:=-1;
 For I:=0 To 16 Do If Names[I]=S Then Begin
  If I=16 Then ColorByName:=7 Else ColorByName:=I;
 End;
End;

{ ====================================================================
  Chargement du modele anatomique 3D (.C3D ou .OBJ)
  ==================================================================== }

Procedure ClearModel;
Begin
 NV:=0; NF:=0; NS:=0; NVes:=0; NPts:=0; NView:=0; ModelName:='';
 NPart:=0; Sel:=0; NOld:=0;
End;

Procedure ReadC3D(Var T:Text);
Var
 Line,Key,A:String;
 VB,SB,I,N,Id,Cur:Integer;
 PX,PY,PZ,PR:Real;
 Idx:Array[1..4] Of Integer;
 Ok:Boolean;
Begin
 VB:=NV; SB:=NS; Cur:=0;
 While Not Eof(T) Do Begin
  ReadLn(T,Line);
  Line:=TrimStr(Line);
  If (Length(Line)>0)And(Line[1]<>';') Then Begin
   Key:=UpStr(NextTok(Line));
   If Key='V' Then Begin
    PX:=StrReal(NextTok(Line),0);
    PY:=StrReal(NextTok(Line),0);
    PZ:=StrReal(NextTok(Line),0);
    If NV<MaxV Then Begin
     Inc(NV);
     Vtx^[NV].X:=PX; Vtx^[NV].Y:=PY; Vtx^[NV].Z:=PZ; Vtx^[NV].S:=0;
    End;
   End
    Else
   If Key='F' Then Begin
    Id:=StrInt(NextTok(Line),0)+SB;
    N:=0;
    Repeat
     A:=NextTok(Line);
     If (A<>'')And(N<4) Then Begin
      Inc(N);
      Idx[N]:=StrInt(A,0)+VB;
     End;
    Until A='';
    Ok:=(N>=3)And(NF<MaxF)And(Id>SB)And(Id<=NS);
    For I:=1 To N Do If (Idx[I]<1)Or(Idx[I]>NV) Then Ok:=False;
    If Ok Then Begin
     Inc(NF);
     Faces^[NF].S:=Id; Faces^[NF].N:=N;
     For I:=1 To 4 Do Begin
      If I<=N Then Faces^[NF].V[I]:=Idx[I] Else Faces^[NF].V[I]:=0;
     End;
     For I:=1 To N Do If Vtx^[Idx[I]].S=0 Then Vtx^[Idx[I]].S:=Id;
    End;
   End
    Else
   If Key='STRUCT' Then Begin
    If NS<MaxS Then Begin
     Inc(NS);
     Structs[NS].Name:=NextTok(Line);
     A:=UpStr(NextTok(Line));
     If A='BODY' Then Structs[NS].Kind:=0 Else
     If A='HEART' Then Structs[NS].Kind:=1 Else
     If A='LUNG' Then Structs[NS].Kind:=2 Else Structs[NS].Kind:=3;
     A:=UpStr(NextTok(Line));
     If A='WIRE' Then Structs[NS].Style:=1 Else
     If A='SEMI' Then Structs[NS].Style:=2 Else Structs[NS].Style:=0;
     Structs[NS].Col:=StrInt(NextTok(Line),7) And 15;
     Structs[NS].Dark:=StrInt(NextTok(Line),Structs[NS].Col) And 15;
     A:=UpStr(NextTok(Line));
     If (A='A')Or(A='V') Then Structs[NS].Beat:=A[1] Else Structs[NS].Beat:='N';
     Structs[NS].CX:=StrReal(NextTok(Line),0);
     Structs[NS].CY:=StrReal(NextTok(Line),0);
     Structs[NS].CZ:=StrReal(NextTok(Line),0);
    End;
   End
    Else
   If Key='VESSEL' Then Begin
    If NVes<MaxVes Then Begin
     Inc(NVes); Cur:=NVes;
     Ves[Cur].Name:=NextTok(Line);
     A:=UpStr(NextTok(Line));
     If A='VEIN' Then Ves[Cur].VT:=1 Else
     If A='CAPILLARY' Then Ves[Cur].VT:=2 Else Ves[Cur].VT:=0;
     A:=UpStr(NextTok(Line));
     If A='PUL' Then Ves[Cur].Circ:=1 Else Ves[Cur].Circ:=0;
     Ves[Cur].SatA:=StrInt(NextTok(Line),98);
     Ves[Cur].SatB:=StrInt(NextTok(Line),98);
     Ves[Cur].Lbl:=StrInt(NextTok(Line),0)<>0;
     Ves[Cur].Vel:=StrReal(NextTok(Line),0);
     Ves[Cur].Len:=0; Ves[Cur].First:=NPts+1; Ves[Cur].Cnt:=0;
     Ves[Cur].PFirst:=1; Ves[Cur].PCnt:=0;
    End
     Else
    Cur:=0;
   End
    Else
   If Key='P' Then Begin
    If (Cur>0)And(NPts<MaxPts) Then Begin
     PX:=StrReal(NextTok(Line),0);
     PY:=StrReal(NextTok(Line),0);
     PZ:=StrReal(NextTok(Line),0);
     PR:=StrReal(NextTok(Line),0.3);
     Inc(NPts);
     Pts^[NPts].X:=PX; Pts^[NPts].Y:=PY; Pts^[NPts].Z:=PZ; Pts^[NPts].R:=PR;
     Pts^[NPts].V:=Cur;
     If Ves[Cur].Cnt=0 Then Pts^[NPts].L:=0 Else
      Pts^[NPts].L:=Pts^[NPts-1].L+Sqrt(Sqr(PX-Pts^[NPts-1].X)+
       Sqr(PY-Pts^[NPts-1].Y)+Sqr(PZ-Pts^[NPts-1].Z));
     Inc(Ves[Cur].Cnt);
     Ves[Cur].Len:=Pts^[NPts].L;
    End;
   End
    Else
   If Key='VIEW' Then Begin
    If NView<MaxView Then Begin
     Inc(NView);
     Views[NView].Name:=UpStr(NextTok(Line));
     Views[NView].X:=StrReal(NextTok(Line),0);
     Views[NView].Y:=StrReal(NextTok(Line),90);
     Views[NView].Z:=StrReal(NextTok(Line),0);
     Views[NView].Zoom:=StrReal(NextTok(Line),1);
    End;
   End
    Else
   If Key='NAME' Then ModelName:=NextTok(Line);
  End;
 End;
End;

Procedure ReadOBJ(Var T:Text);
Var
 Line,Key,A:String;
 VB,SId,I,N,P:Integer;
 PX,PY,PZ:Real;
 Idx:Array[1..16] Of Integer;
Begin
 VB:=NV;
 If NS<MaxS Then Begin
  Inc(NS); SId:=NS;
  Structs[SId].Name:='OBJ'; Structs[SId].Kind:=3; Structs[SId].Style:=0;
  Structs[SId].Col:=LightRed; Structs[SId].Dark:=Red; Structs[SId].Beat:='N';
  Structs[SId].CX:=0; Structs[SId].CY:=0; Structs[SId].CZ:=0;
 End
  Else
 Exit;
 While Not Eof(T) Do Begin
  ReadLn(T,Line);
  Line:=TrimStr(Line);
  Key:=NextTok(Line);
  If Key='v' Then Begin
   PX:=StrReal(NextTok(Line),0);
   PY:=StrReal(NextTok(Line),0);
   PZ:=StrReal(NextTok(Line),0);
   If NV<MaxV Then Begin
    Inc(NV);
    Vtx^[NV].X:=PX; Vtx^[NV].Y:=PY; Vtx^[NV].Z:=PZ; Vtx^[NV].S:=SId;
   End;
  End
   Else
  If Key='f' Then Begin
   N:=0;
   Repeat
    A:=NextTok(Line);
    If (A<>'')And(N<16) Then Begin
     P:=Pos('/',A);
     If P>0 Then A:=Copy(A,1,P-1);
     Inc(N);
     Idx[N]:=StrInt(A,0)+VB;
    End;
   Until A='';
   If N>=3 Then Begin
    I:=2;
    While (I<N)And(NF<MaxF) Do Begin
     Inc(NF);
     Faces^[NF].S:=SId; Faces^[NF].N:=3;
     Faces^[NF].V[1]:=Idx[1]; Faces^[NF].V[2]:=Idx[I]; Faces^[NF].V[3]:=Idx[I+1];
     Faces^[NF].V[4]:=0;
     Inc(I);
    End;
   End;
  End;
 End;
 { Elimine les faces dont les indices sont invalides }
 N:=0;
 For I:=1 To NF Do Begin
  If (Faces^[I].V[1]>=1)And(Faces^[I].V[1]<=NV)And(Faces^[I].V[2]>=1)And
     (Faces^[I].V[2]<=NV)And(Faces^[I].V[3]>=1)And(Faces^[I].V[3]<=NV) Then Begin
   Inc(N);
   Faces^[N]:=Faces^[I];
  End;
 End;
 NF:=N;
End;

Procedure ResetParticles;
Var
 I,J:Integer;
Begin
 For I:=1 To NVes Do
  For J:=1 To Ves[I].PCnt Do
   PartT[Ves[I].PFirst+J-1]:=(J-1)/Ves[I].PCnt+Random*0.4/Ves[I].PCnt;
 NOld:=0;
End;

Procedure FinishModel;
Var
 I,N:Integer;
Begin
 NPart:=0;
 For I:=1 To NVes Do Begin
  If Ves[I].Len<0.1 Then Ves[I].Len:=0.1;
  N:=1+Trunc(Ves[I].Len/12.0);
  If N>6 Then N:=6;
  If Ves[I].Cnt<2 Then N:=0;
  If NPart+N>MaxPart Then N:=MaxPart-NPart;
  Ves[I].PFirst:=NPart+1;
  Ves[I].PCnt:=N;
  Inc(NPart,N);
 End;
 ResetParticles;
End;

Function LoadModel(Fn:String;Append:Boolean):Boolean;
Var
 T:Text;
 Path,Ext:String;
 N:Integer;
Begin
 LoadModel:=False;
 Path:=FindFile(Fn);
 If Path='' Then Begin
  Warn('Fichier introuvable : '+Fn);
  Exit;
 End;
 Assign(T,Path);
 {$I-}Reset(T);{$I+}
 If IOResult<>0 Then Begin
  Warn('Impossible d''ouvrir : '+Path);
  Exit;
 End;
 If Not Append Then ClearModel;
 N:=Length(Path);
 Ext:=UpStr(Copy(Path,N-3,4));
 If Ext='.OBJ' Then ReadOBJ(T) Else ReadC3D(T);
 Close(T);
 FinishModel;
 Info('Modele '+Path+' : '+IntStr(NV)+' sommets, '+IntStr(NF)+' faces, '+
      IntStr(NVes)+' vaisseaux, '+IntStr(NS)+' structures');
 LoadModel:=(NV>0)Or(NVes>0);
End;

{ ====================================================================
  Physiologie du cycle cardiaque
  ==================================================================== }

Function Gauss(F,C,W:Real):Real;
Begin
 If Abs(F-C)>4*W Then Gauss:=0 Else Gauss:=Exp(-Sqr((F-C)/W));
End;

Function AtrAct(F:Real):Real;
Begin
 If (F>=A0)And(F<A1) Then AtrAct:=Sin(Pi*(F-A0)/(A1-A0)) Else AtrAct:=0;
End;

Function VentAct(F:Real):Real;
Begin
 If (F>=V0)And(F<V1) Then VentAct:=Sin(Pi*(F-V0)/(V1-V0)) Else VentAct:=0;
End;

Function EcgAt(F:Real):Real;
Var
 CP,CR:Real;
Begin
 CP:=(A0+A1)/2; CR:=V0+0.005;
 EcgAt:=0.12*Gauss(F,CP,0.025)-0.12*Gauss(F,CR-0.02,0.008)+Gauss(F,CR,0.009)
        -0.25*Gauss(F,CR+0.017,0.008)+0.28*Gauss(F,V1-0.11,0.04);
End;

{ Pression aortique normalisee 0..1 }
Function PresAt(F:Real):Real;
Var
 VP,W:Real;
Begin
 VP:=V0+0.3*(V1-V0);
 If (F>=V0)And(F<VP) Then W:=Sin(Pi/2*(F-V0)/(VP-V0)) Else
 If (F>=VP)And(F<V1) Then W:=1-0.25*(F-VP)/(V1-VP) Else
 If F>=V1 Then W:=0.75*Exp(-(F-V1)/0.2) Else W:=0.75*Exp(-(F+1-V1)/0.2);
 PresAt:=W;
End;

{ Volume du ventricule gauche (mL) }
Function VolAt(F:Real):Real;
Var
 Edv,Esv,Tau,Fill,Prog:Real;
Begin
 Esv:=EsvBase; Edv:=Esv+SV;
 If (F>=V0)And(F<V1) Then Begin
  Prog:=(1-Cos(Pi*(F-V0)/(V1-V0)))/2;
  VolAt:=Edv-(Edv-Esv)*Prog;
 End
  Else
 Begin
  If F>=V1 Then Tau:=F-V1 Else Tau:=F+1-V1;
  Fill:=(1-Exp(-Tau/0.15))/(1-Exp(-(1+V0-V1)/0.15));
  VolAt:=Esv+(Edv-Esv)*Fill;
 End;
End;

Procedure BuildTables;
Var
 I:Integer;
Begin
 For I:=0 To 255 Do Begin
  EcgTab[I]:=Round(EcgAt(I/256)*1000);
  PresTab[I]:=Round(PresAt(I/256)*1000);
 End;
End;

Function FracPart(R:Real):Real;
Begin
 FracPart:=R-Int(R);
 If R-Int(R)<0 Then FracPart:=R-Int(R)+1;
End;

Function PhaseName:String;
Begin
 If AtrAct(PhaseF)>0 Then PhaseName:='Systole auric.' Else
 If VentAct(PhaseF)>0 Then PhaseName:='Systole ventric.' Else
 PhaseName:='Diastole';
End;

Function CardiacOutput:Real;
Begin
 CardiacOutput:=HR*SV/1000.0;
End;

Procedure UpdatePhase;
Var
 QV,QA:Real;
Begin
 PhaseF:=FracPart(CycleAcc);
 QV:=Round(VentAct(PhaseF)*8)/8;
 QA:=Round(AtrAct(PhaseF)*8)/8;
 KV:=1-BeatV*QV;
 KA:=1-BeatA*QA+0.4*BeatA*QV;
 HeartKey:=Round(QV*8)*16+Round(QA*8);
End;

Function ApplyProfile(Nm:String):Boolean;
Var
 I:Integer;
Begin
 ApplyProfile:=False;
 Nm:=UpStr(Nm);
 For I:=1 To NProf Do If UpStr(Profs[I].Name)=Nm Then Begin
  HR:=Profs[I].HR; PSys:=Profs[I].Sys; PDia:=Profs[I].Dia; SV:=Profs[I].SV;
  SpeedF:=Profs[I].Spd;
  ApplyProfile:=True;
 End;
End;

Procedure DefaultPhysio;
Begin
 A0:=0.0; A1:=0.11; V0:=0.13; V1:=0.47;
 BeatV:=0.13; BeatA:=0.11; Pulsat:=1.3;
 VelType[0]:=35; VelType[1]:=20; VelType[2]:=6;
 SatArt:=98; SatVen:=75; EsvBase:=50;
 HR:=72; PSys:=120; PDia:=80; SV:=70; SpeedF:=1.0;
 NProf:=1;
 Profs[1].Name:='REST'; Profs[1].HR:=72; Profs[1].Sys:=120; Profs[1].Dia:=80;
 Profs[1].SV:=70; Profs[1].Spd:=1.0;
End;

Procedure LoadPhysio(Fn:String);
Var
 T:Text;
 Path,Line,Key,A,K,V:String;
 P:Integer;
 First:Boolean;
Begin
 Path:=FindFile(Fn);
 If Path='' Then Begin
  Warn('Configuration physiologique introuvable ('+Fn+'), valeurs par defaut');
  Exit;
 End;
 Assign(T,Path);
 {$I-}Reset(T);{$I+}
 If IOResult<>0 Then Exit;
 First:=True;
 While Not Eof(T) Do Begin
  ReadLn(T,Line);
  Line:=TrimStr(Line);
  If (Length(Line)>0)And(Line[1]<>';') Then Begin
   Key:=UpStr(NextTok(Line));
   If Key='CYCLE' Then Begin
    A0:=StrReal(NextTok(Line),A0); A1:=StrReal(NextTok(Line),A1);
    V0:=StrReal(NextTok(Line),V0); V1:=StrReal(NextTok(Line),V1);
   End
    Else
   If Key='BEAT' Then Begin
    A:=UpStr(NextTok(Line));
    If A='VENTRICLE' Then BeatV:=StrReal(NextTok(Line),BeatV) Else
    If A='ATRIUM' Then BeatA:=StrReal(NextTok(Line),BeatA);
   End
    Else
   If Key='VELOCITY' Then Begin
    A:=UpStr(NextTok(Line));
    If A='ARTERY' Then VelType[0]:=StrReal(NextTok(Line),35) Else
    If A='VEIN' Then VelType[1]:=StrReal(NextTok(Line),20) Else
    If A='CAPILLARY' Then VelType[2]:=StrReal(NextTok(Line),6);
   End
    Else
   If Key='PULSATILITY' Then Pulsat:=StrReal(NextTok(Line),Pulsat) Else
   If Key='SATURATION' Then Begin
    SatArt:=StrInt(NextTok(Line),98); SatVen:=StrInt(NextTok(Line),75);
   End
    Else
   If Key='ESV_BASE' Then EsvBase:=StrInt(NextTok(Line),50) Else
   If Key='PROFILE' Then Begin
    If First Then Begin NProf:=0; First:=False; End;
    If NProf<MaxProf Then Begin
     Inc(NProf);
     Profs[NProf].Name:=NextTok(Line);
     Profs[NProf].HR:=72; Profs[NProf].Sys:=120; Profs[NProf].Dia:=80;
     Profs[NProf].SV:=70; Profs[NProf].Spd:=1.0;
     Repeat
      A:=NextTok(Line);
      P:=Pos('=',A);
      If P>0 Then Begin
       K:=UpStr(Copy(A,1,P-1)); V:=Copy(A,P+1,20);
       If K='HR' Then Profs[NProf].HR:=StrInt(V,72) Else
       If K='SYS' Then Profs[NProf].Sys:=StrInt(V,120) Else
       If K='DIA' Then Profs[NProf].Dia:=StrInt(V,80) Else
       If K='SV' Then Profs[NProf].SV:=StrInt(V,70) Else
       If K='SPEED' Then Profs[NProf].Spd:=StrReal(V,1.0);
      End;
     Until A='';
    End;
   End;
  End;
 End;
 Close(T);
 Info('Physiologie '+Path+' : '+IntStr(NProf)+' profils');
End;

{ ====================================================================
  Camera, vues et visibilite
  ==================================================================== }

Procedure Layout;
Begin
 VX1:=0; VY1:=MenuH;
 If ShowInfo Then VX2:=ScrW-InfoW-1 Else VX2:=ScrW-1;
 If ShowTrace Then VY2:=ScrH-StatH-TrH-1 Else VY2:=ScrH-StatH-1;
 VW:=VX2-VX1+1; VH:=VY2-VY1+1;
 InfoX:=ScrW-InfoW;
 TrY:=ScrH-StatH-TrH;
 TrW:=ScrW-TrLeft-8;
 BaseScale:=VH/195.0;
 If VW/92.0<BaseScale Then BaseScale:=VW/92.0;
End;

Procedure SetCamera(Nm:String);
Begin
 Nm:=UpStr(Nm);
 Orbit:=False;
 If (Nm='FRONT')Or(Nm='FACE') Then Begin Yaw:=0; Pitch:=0; End Else
 If (Nm='BACK')Or(Nm='DOS') Then Begin Yaw:=180; Pitch:=0; End Else
 If (Nm='LEFT')Or(Nm='GAUCHE') Then Begin Yaw:=-90; Pitch:=0; End Else
 If (Nm='RIGHT')Or(Nm='DROITE') Then Begin Yaw:=90; Pitch:=0; End Else
 If (Nm='TOP')Or(Nm='DESSUS') Then Begin Yaw:=0; Pitch:=85; End Else
 If (Nm='BOTTOM')Or(Nm='DESSOUS') Then Begin Yaw:=0; Pitch:=-85; End Else
 If (Nm='ISO')Or(Nm='ISOMETRIC') Then Begin Yaw:=35; Pitch:=20; End Else
 If Nm='ORBIT' Then Begin Orbit:=True; Pitch:=12; End Else
 Warn('Camera inconnue : '+Nm);
 NeedFull:=True;
End;

Function ApplyView(Nm:String):Boolean;
Var
 I:Integer;
 Found:Boolean;
Begin
 Found:=False;
 Nm:=UpStr(Nm);
 If Nm='BODY' Then Nm:='FULLBODY';
 For I:=1 To NView Do If Views[I].Name=Nm Then Begin
  TgX:=Views[I].X; TgY:=Views[I].Y; TgZ:=Views[I].Z; Zoom:=Views[I].Zoom;
  OffX:=0; OffY:=0; CurView:=Nm;
  Found:=True;
 End;
 If Not Found Then Begin
  If Nm='FULLBODY' Then Begin
   TgX:=0; TgY:=90; TgZ:=0; Zoom:=1.0; OffX:=0; OffY:=0; CurView:=Nm;
   Found:=True;
  End
   Else
  Warn('Vue inconnue : '+Nm);
 End;
 ApplyView:=Found;
 NeedFull:=True;
End;

Procedure SetShow(Tok:String;V:Boolean);
Begin
 Tok:=UpStr(Tok);
 If (Tok='ARTERIES')Or(Tok='ARTERY') Then ShowArt:=V Else
 If (Tok='VEINS')Or(Tok='VEIN') Then ShowVein:=V Else
 If (Tok='CAPILLARIES')Or(Tok='CAPILLARY') Then ShowCap:=V Else
 If Tok='HEART' Then ShowHeart:=V Else
 If (Tok='LUNGS')Or(Tok='LUNG') Then ShowLung:=V Else
 If Tok='BODY' Then ShowBody:=V Else
 If (Tok='BLOOD')Or(Tok='PARTICLES') Then ShowBlood:=V Else
 If Tok='LABELS' Then ShowLabels:=V Else
 If Tok='INFO' Then ShowInfo:=V Else
 If (Tok='ECG')Or(Tok='TRACE') Then ShowTrace:=V Else
 If Tok='ALL' Then Begin
  ShowArt:=V; ShowVein:=V; ShowCap:=V; ShowHeart:=V; ShowLung:=V; ShowBody:=V;
 End
  Else
 Warn('Element inconnu : '+Tok);
End;

Procedure ShowHideList(L:String;V:Boolean);
Var
 P:Integer;
 Tok:String;
Begin
 If V And Not ShowListed Then Begin
  { Premier /SHOW : on ne montre que les structures listees }
  ShowArt:=False; ShowVein:=False; ShowCap:=False;
  ShowHeart:=False; ShowLung:=False; ShowBody:=False;
  ShowListed:=True;
 End;
 L:=L+',';
 P:=Pos(',',L);
 While P>0 Do Begin
  Tok:=TrimStr(Copy(L,1,P-1));
  If Tok<>'' Then SetShow(Tok,V);
  Delete(L,1,P);
  P:=Pos(',',L);
 End;
 NeedAll:=True;
End;

Procedure SetVessels(L:String);
Var
 P:Integer;
 Tok:String;
 HasT,HasC:Boolean;
 TA,TV,TC,CS,CP:Boolean;
Begin
 TA:=False; TV:=False; TC:=False; CS:=False; CP:=False; HasT:=False; HasC:=False;
 L:=L+',';
 P:=Pos(',',L);
 While P>0 Do Begin
  Tok:=UpStr(TrimStr(Copy(L,1,P-1)));
  If Tok='ALL' Then Begin
   TA:=True; TV:=True; TC:=True; CS:=True; CP:=True; HasT:=True; HasC:=True;
  End
   Else
  If (Tok='ARTERIES')Or(Tok='ARTERY') Then Begin TA:=True; HasT:=True; End Else
  If (Tok='VEINS')Or(Tok='VEIN') Then Begin TV:=True; HasT:=True; End Else
  If (Tok='CAPILLARIES')Or(Tok='CAPILLARY') Then Begin TC:=True; HasT:=True; End Else
  If (Tok='SYSTEMIC')Or(Tok='SYS') Then Begin CS:=True; HasC:=True; End Else
  If (Tok='PULMONARY')Or(Tok='PUL') Then Begin CP:=True; HasC:=True; End Else
  If Tok<>'' Then Warn('Type de vaisseaux inconnu : '+Tok);
  Delete(L,1,P);
  P:=Pos(',',L);
 End;
 If HasT Then Begin ShowArt:=TA; ShowVein:=TV; ShowCap:=TC; End;
 If HasC Then Begin ShowSys:=CS; ShowPul:=CP; End;
 NeedAll:=True;
End;

Function StructOn(S:Integer):Boolean;
Begin
 Case Structs[S].Kind Of
  0:StructOn:=ShowBody;
  1:StructOn:=ShowHeart;
  2:StructOn:=ShowLung;
 Else
  StructOn:=True;
 End;
End;

Function VesOn(V:Integer):Boolean;
Var
 Ok:Boolean;
Begin
 Case Ves[V].VT Of
  0:Ok:=ShowArt;
  1:Ok:=ShowVein;
 Else
  Ok:=ShowCap;
 End;
 If Ves[V].Circ=0 Then Ok:=Ok And ShowSys Else Ok:=Ok And ShowPul;
 VesOn:=Ok And (Ves[V].Cnt>=2);
End;

{ ====================================================================
  Projection 3D
  ==================================================================== }

Procedure ProjectAll;
Var
 I,S:Integer;
 CYw,SYw,CPt,SPt,Sc,F,X,Y,Z,X1,Z1,Y2,Z2,K,Dd:Real;
Begin
 CYw:=Cos(Yaw*Pi/180); SYw:=Sin(Yaw*Pi/180);
 CPt:=Cos(Pitch*Pi/180); SPt:=Sin(Pitch*Pi/180);
 Sc:=BaseScale*Zoom;
 CX0:=VW Div 2+OffX; CY0:=VH Div 2+OffY;
 PHX1:=HX1; PHY1:=HY1; PHX2:=HX2; PHY2:=HY2;
 HX1:=32000; HY1:=32000; HX2:=-32000; HY2:=-32000;
 For I:=1 To NV Do Begin
  X:=Vtx^[I].X; Y:=Vtx^[I].Y; Z:=Vtx^[I].Z;
  S:=Vtx^[I].S;
  If S>0 Then If Structs[S].Beat<>'N' Then Begin
   If Structs[S].Beat='V' Then K:=KV Else K:=KA;
   X:=Structs[S].CX+(X-Structs[S].CX)*K;
   Y:=Structs[S].CY+(Y-Structs[S].CY)*K;
   Z:=Structs[S].CZ+(Z-Structs[S].CZ)*K;
  End;
  X:=X-TgX; Y:=Y-TgY; Z:=Z-TgZ;
  X1:=X*CYw+Z*SYw; Z1:=-X*SYw+Z*CYw;
  Y2:=Y*CPt-Z1*SPt; Z2:=Y*SPt+Z1*CPt;
  VCam^[I].X:=X1; VCam^[I].Y:=Y2; VCam^[I].Z:=Z2;
  Dd:=CamDist-Z2; If Dd<20 Then Dd:=20;
  F:=CamDist/Dd;
  Vsc^[I].X:=ClampI(CX0+X1*Sc*F);
  Vsc^[I].Y:=ClampI(CY0-Y2*Sc*F);
  If S>0 Then If Structs[S].Kind=1 Then Begin
   If Vsc^[I].X<HX1 Then HX1:=Vsc^[I].X;
   If Vsc^[I].X>HX2 Then HX2:=Vsc^[I].X;
   If Vsc^[I].Y<HY1 Then HY1:=Vsc^[I].Y;
   If Vsc^[I].Y>HY2 Then HY2:=Vsc^[I].Y;
  End;
 End;
 For I:=1 To NPts Do Begin
  X:=Pts^[I].X-TgX; Y:=Pts^[I].Y-TgY; Z:=Pts^[I].Z-TgZ;
  X1:=X*CYw+Z*SYw; Z1:=-X*SYw+Z*CYw;
  Y2:=Y*CPt-Z1*SPt; Z2:=Y*SPt+Z1*CPt;
  PCam^[I].X:=X1; PCam^[I].Y:=Y2; PCam^[I].Z:=Z2;
  Dd:=CamDist-Z2; If Dd<20 Then Dd:=20;
  F:=CamDist/Dd;
  Psc^[I].X:=ClampI(CX0+X1*Sc*F);
  Psc^[I].Y:=ClampI(CY0-Y2*Sc*F);
  K:=Pts^[I].R*Sc*F*(1.0+1.0/Zoom)*10;
  If K<6 Then K:=6;
  Psc^[I].R:=ClampI(K);
 End;
End;

{ ====================================================================
  Dessin de la scene 3D
  ==================================================================== }

Function SatColor(Sat:Integer):Integer;
Begin
 If OxyMode=0 Then SatColor:=LightGray Else
 If Sat>=90 Then SatColor:=LightRed Else
 If Sat>=81 Then SatColor:=LightMagenta Else
 SatColor:=LightBlue;
End;

Function EdgeColor(C:Integer):Integer;
Begin
 If C=LightRed Then EdgeColor:=Red Else
 If C=LightBlue Then EdgeColor:=Blue Else
 If C=LightMagenta Then EdgeColor:=Magenta Else
 If C=Yellow Then EdgeColor:=Brown Else
 EdgeColor:=DarkGray;
End;

Function SegColor(K:Integer):Integer;
Var
 V,Sat:Integer;
 U:Real;
Begin
 V:=Pts^[K].V;
 If V=Sel Then Begin
  SegColor:=Yellow;
  Exit;
 End;
 If OxyMode=2 Then Begin
  U:=(Pts^[K].L+Pts^[K+1].L)/2/Ves[V].Len;
  Sat:=Ves[V].SatA+Round((Ves[V].SatB-Ves[V].SatA)*U);
 End
  Else
 Sat:=(Ves[V].SatA+Ves[V].SatB) Div 2;
 SegColor:=SatColor(Sat);
End;

Procedure DrawSeg(K:Integer);
Var
 X1,Y1,X2,Y2,R1,R2,Fc,Ec,RP:Integer;
 DXs,DYs,Lg,NX,NY:Real;
Begin
 X1:=Psc^[K].X-OX; Y1:=Psc^[K].Y-OY;
 X2:=Psc^[K+1].X-OX; Y2:=Psc^[K+1].Y-OY;
 R1:=Psc^[K].R; R2:=Psc^[K+1].R;
 Fc:=SegColor(K); Ec:=EdgeColor(Fc);
 If (R1<18)And(R2<18) Then Begin
  SetColor(Fc);
  If (R1>=9)Or(R2>=9) Then SetLineStyle(SolidLn,0,ThickWidth);
  Line(X1,Y1,X2,Y2);
  SetLineStyle(SolidLn,0,NormWidth);
 End
  Else
 Begin
  DXs:=X2-X1; DYs:=Y2-Y1;
  Lg:=Sqrt(DXs*DXs+DYs*DYs);
  SetFillStyle(SolidFill,Fc);
  SetColor(Fc);
  If Lg>=1 Then Begin
   NX:=-DYs/Lg; NY:=DXs/Lg;
   Poly[1].X:=Round(X1+NX*R1/10); Poly[1].Y:=Round(Y1+NY*R1/10);
   Poly[2].X:=Round(X2+NX*R2/10); Poly[2].Y:=Round(Y2+NY*R2/10);
   Poly[3].X:=Round(X2-NX*R2/10); Poly[3].Y:=Round(Y2-NY*R2/10);
   Poly[4].X:=Round(X1-NX*R1/10); Poly[4].Y:=Round(Y1-NY*R1/10);
   FillPoly(4,Poly);
   RP:=R2 Div 10;
   FillEllipse(X2,Y2,RP,RP);
   If (K=Pts^[K].V)Or(Pts^[K-1].V<>Pts^[K].V)Or(K=1) Then Begin
    RP:=R1 Div 10;
    FillEllipse(X1,Y1,RP,RP);
   End;
   If (R1>=30)Or(R2>=30) Then Begin
    SetColor(Ec);
    Line(Poly[1].X,Poly[1].Y,Poly[2].X,Poly[2].Y);
    Line(Poly[3].X,Poly[3].Y,Poly[4].X,Poly[4].Y);
   End;
  End
   Else
  Begin
   RP:=R2 Div 10;
   FillEllipse(X2,Y2,RP,RP);
  End;
 End;
End;

Procedure DrawFace(I:Integer);
Var
 K,S,N,A,B,C:Integer;
 AX,AY,AZ,BX,BY,BZ,NX,NY,NZ,Ln,Lm:Real;
 Fc:Integer;
Begin
 S:=Faces^[I].S; N:=Faces^[I].N;
 For K:=1 To N Do Begin
  Poly[K].X:=Vsc^[Faces^[I].V[K]].X-OX;
  Poly[K].Y:=Vsc^[Faces^[I].V[K]].Y-OY;
 End;
 If Structs[S].Style=1 Then Begin
  Poly[N+1]:=Poly[1];
  SetColor(Structs[S].Col);
  DrawPoly(N+1,Poly);
 End
  Else
 If Structs[S].Style=2 Then Begin
  SetFillStyle(LtSlashFill,Structs[S].Col);
  SetColor(Structs[S].Dark);
  FillPoly(N,Poly);
 End
  Else
 Begin
  A:=Faces^[I].V[1]; B:=Faces^[I].V[2]; C:=Faces^[I].V[3];
  AX:=VCam^[B].X-VCam^[A].X; AY:=VCam^[B].Y-VCam^[A].Y; AZ:=VCam^[B].Z-VCam^[A].Z;
  BX:=VCam^[C].X-VCam^[A].X; BY:=VCam^[C].Y-VCam^[A].Y; BZ:=VCam^[C].Z-VCam^[A].Z;
  NX:=AY*BZ-AZ*BY; NY:=AZ*BX-AX*BZ; NZ:=AX*BY-AY*BX;
  Ln:=Sqrt(NX*NX+NY*NY+NZ*NZ);
  If Ln<0.0001 Then Ln:=1;
  Lm:=(-0.35*NX+0.55*NY+0.75*NZ)/Ln;
  If Lm>0.45 Then Fc:=Structs[S].Col Else Fc:=Structs[S].Dark;
  SetFillStyle(SolidFill,Fc);
  SetColor(Structs[S].Dark);
  If Fc=Structs[S].Dark Then SetColor(Structs[S].Col);
  FillPoly(N,Poly);
 End;
End;

{ La face est-elle dirigee vers la camera ? }
Function FaceVisible(I:Integer):Boolean;
Var
 A,B,C:Integer;
Begin
 A:=Faces^[I].V[1]; B:=Faces^[I].V[2]; C:=Faces^[I].V[3];
 FaceVisible:=((VCam^[B].X-VCam^[A].X)*(VCam^[C].Y-VCam^[A].Y)-
               (VCam^[B].Y-VCam^[A].Y)*(VCam^[C].X-VCam^[A].X))>0;
End;

Function ItemInRegion(Kind,Idx,RX1,RY1,RX2,RY2:Integer):Boolean;
Var
 K,X1,Y1,X2,Y2,V:Integer;
Begin
 If Kind=0 Then Begin
  V:=Faces^[Idx].V[1];
  X1:=Vsc^[V].X; X2:=X1; Y1:=Vsc^[V].Y; Y2:=Y1;
  For K:=2 To Faces^[Idx].N Do Begin
   V:=Faces^[Idx].V[K];
   If Vsc^[V].X<X1 Then X1:=Vsc^[V].X;
   If Vsc^[V].X>X2 Then X2:=Vsc^[V].X;
   If Vsc^[V].Y<Y1 Then Y1:=Vsc^[V].Y;
   If Vsc^[V].Y>Y2 Then Y2:=Vsc^[V].Y;
  End;
 End
  Else
 Begin
  X1:=MinI(Psc^[Idx].X,Psc^[Idx+1].X)-(MaxI(Psc^[Idx].R,Psc^[Idx+1].R) Div 10)-2;
  X2:=MaxI(Psc^[Idx].X,Psc^[Idx+1].X)+(MaxI(Psc^[Idx].R,Psc^[Idx+1].R) Div 10)+2;
  Y1:=MinI(Psc^[Idx].Y,Psc^[Idx+1].Y)-(MaxI(Psc^[Idx].R,Psc^[Idx+1].R) Div 10)-2;
  Y2:=MaxI(Psc^[Idx].Y,Psc^[Idx+1].Y)+(MaxI(Psc^[Idx].R,Psc^[Idx+1].R) Div 10)+2;
 End;
 ItemInRegion:=(X2>=RX1)And(X1<=RX2)And(Y2>=RY1)And(Y1<=RY2);
End;

Procedure BuildItems;
Var
 I,K,V,S,N,Gap,J,Tmp,Key:Integer;
Begin
 N:=0;
 For I:=1 To NF Do Begin
  S:=Faces^[I].S;
  If StructOn(S)And(Structs[S].Style=0) Then Begin
   If FaceVisible(I) Then Begin
    Key:=0;
    For K:=1 To Faces^[I].N Do Key:=Key+Round(VCam^[Faces^[I].V[K]].Z*8) Div Faces^[I].N;
    If N<MaxItem Then Begin
     Inc(N); ItKind[N]:=0; ItIdx[N]:=I; ItKey[N]:=Key;
    End;
   End;
  End;
 End;
 For V:=1 To NVes Do If VesOn(V) Then
  For K:=Ves[V].First To Ves[V].First+Ves[V].Cnt-2 Do Begin
   If N<MaxItem Then Begin
    Inc(N); ItKind[N]:=1; ItIdx[N]:=K;
    ItKey[N]:=Round((PCam^[K].Z+PCam^[K+1].Z)*4);
   End;
  End;
 NItems:=N;
 For I:=1 To N Do ItOrd[I]:=I;
 Gap:=N Div 2;
 While Gap>0 Do Begin
  For I:=Gap+1 To N Do Begin
   Tmp:=ItOrd[I]; J:=I;
   While (J>Gap)And(ItKey[ItOrd[J-Gap]]>ItKey[Tmp]) Do Begin
    ItOrd[J]:=ItOrd[J-Gap];
    J:=J-Gap;
   End;
   ItOrd[J]:=Tmp;
  End;
  Gap:=Gap Div 2;
 End;
End;

Procedure DrawLabel(X,Y:Integer;S:String);
Var
 I:Integer;
 Free:Boolean;
Begin
 For I:=1 To Length(S) Do If S[I]='_' Then S[I]:=' ';
 If Length(S)>22 Then S:=Copy(S,1,22);
 Free:=True;
 For I:=1 To NLbl Do
  If (Abs(LblX[I]-X)<Length(S)*8)And(Abs(LblY[I]-Y)<10) Then Free:=False;
 If Free And (NLbl<60) Then Begin
  Inc(NLbl); LblX[NLbl]:=X; LblY[NLbl]:=Y;
 End;
 If Free And (X>8)And(X<VW-8)And(Y>8)And(Y<VH-8) Then Begin
  SetColor(Black);
  OutTextXY(X+1-OX,Y+1-OY,S);
  SetColor(LightCyan);
  OutTextXY(X-OX,Y-OY,S);
 End;
End;

Procedure DrawArrows;
Var
 V,K,X1,Y1,X2,Y2,MxP,MyP,Ax,Ay:Integer;
 Dx,Dy,Lg:Real;
Begin
 SetColor(White);
 For V:=1 To NVes Do If VesOn(V) Then Begin
  K:=Ves[V].First+(Ves[V].Cnt-1) Div 2;
  If K>=Ves[V].First+Ves[V].Cnt-1 Then K:=K-1;
  X1:=Psc^[K].X-OX; Y1:=Psc^[K].Y-OY; X2:=Psc^[K+1].X-OX; Y2:=Psc^[K+1].Y-OY;
  Dx:=X2-X1; Dy:=Y2-Y1;
  Lg:=Sqrt(Dx*Dx+Dy*Dy);
  If Lg>=8 Then Begin
   Dx:=Dx/Lg; Dy:=Dy/Lg;
   MxP:=(X1+X2) Div 2; MyP:=(Y1+Y2) Div 2;
   Line(MxP-Round(Dx*5),MyP-Round(Dy*5),MxP+Round(Dx*5),MyP+Round(Dy*5));
   Ax:=MxP+Round(Dx*5); Ay:=MyP+Round(Dy*5);
   Line(Ax,Ay,Ax-Round(Dx*5-Dy*3),Ay-Round(Dy*5+Dx*3));
   Line(Ax,Ay,Ax-Round(Dx*5+Dy*3),Ay-Round(Dy*5-Dx*3));
  End;
 End;
End;

{ Dessine la couche statique dans la region (RX1,RY1)-(RX2,RY2) du viewport 3D }
Procedure DrawStatic(Full:Boolean;RX1,RY1,RX2,RY2:Integer);
Var
 I,J,K,V,GX,GY:Integer;
Begin
 SetViewPort(VX1+RX1,VY1+RY1,VX1+RX2,VY1+RY2,True);
 OX:=RX1; OY:=RY1;
 SetFillStyle(SolidFill,BgCol);
 Bar(0,0,RX2-RX1,RY2-RY1);
 If GridOn Then Begin
  SetColor(DarkGray);
  GX:=(RX1 Div 40)*40;
  While GX<=RX2 Do Begin
   Line(GX-OX,0,GX-OX,RY2-RY1);
   Inc(GX,40);
  End;
  GY:=(RY1 Div 40)*40;
  While GY<=RY2 Do Begin
   Line(0,GY-OY,RX2-RX1,GY-OY);
   Inc(GY,40);
  End;
 End;
 { Couche de fond : silhouettes filaires puis surfaces hachurees }
 For J:=1 To 2 Do
  For I:=1 To NF Do Begin
   K:=Faces^[I].S;
   If StructOn(K)And(Structs[K].Style=J) Then
    If (J=1)Or FaceVisible(I) Then
     If Full Or ItemInRegion(0,I,RX1,RY1,RX2,RY2) Then DrawFace(I);
  End;
 BuildItems;
 For I:=1 To NItems Do Begin
  J:=ItOrd[I];
  If Full Or ItemInRegion(ItKind[J],ItIdx[J],RX1,RY1,RX2,RY2) Then Begin
   If ItKind[J]=0 Then DrawFace(ItIdx[J]) Else DrawSeg(ItIdx[J]);
  End;
 End;
 SetLineStyle(SolidLn,0,NormWidth);
 SetFillStyle(SolidFill,White);
 If FlowMode=3 Then DrawArrows;
 If ShowLabels Then Begin
  SetTextStyle(DefaultFont,HorizDir,1);
  NLbl:=0;
  For V:=1 To NVes Do If VesOn(V)And Ves[V].Lbl Then Begin
   K:=Ves[V].First+Ves[V].Cnt Div 2;
   DrawLabel(Psc^[K].X+5,Psc^[K].Y-3,Ves[V].Name);
  End;
 End;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
End;

{ ====================================================================
  Particules sanguines (dessin XOR)
  ==================================================================== }

Function VelOf(V:Integer):Real;
Var
 S:Real;
Begin
 If Ves[V].Vel>0 Then S:=Ves[V].Vel Else S:=VelType[Ves[V].VT];
 If (FlowMode=2)And(Ves[V].VT=0) Then Begin
  S:=S*(0.3+Pulsat*PresTab[Trunc(PhaseF*256) And 255]/1000);
 End;
 S:=S*HR*SV/5040.0;
 VelOf:=S;
End;

Procedure StepParticles(Ds:Real);
Var
 V,J:Integer;
 Sp:Real;
Begin
 For V:=1 To NVes Do If Ves[V].PCnt>0 Then Begin
  Sp:=VelOf(V)*Ds/Ves[V].Len;
  For J:=Ves[V].PFirst To Ves[V].PFirst+Ves[V].PCnt-1 Do Begin
   PartT[J]:=PartT[J]+Sp;
   While PartT[J]>=1 Do PartT[J]:=PartT[J]-1;
  End;
 End;
End;

Procedure XorBlock(X,Y,H,C:Integer);
Var
 K:Integer;
Begin
 SetColor(C);
 For K:=0 To H-1 Do Line(X,Y+K,X+H-1,Y+K);
End;

Procedure EraseParticles;
Var
 I:Integer;
Begin
 SetViewPort(VX1,VY1,VX2,VY2,True);
 SetWriteMode(XORPut);
 For I:=1 To NOld Do XorBlock(OldPX[I],OldPY[I],OldPH[I],OldPC[I]);
 SetWriteMode(NormalPut);
 NOld:=0;
End;

Procedure DrawParticles;
Var
 V,J,K,X,Y,H,C0:Integer;
 U,T:Real;
 Seg:Real;
Begin
 NOld:=0;
 If Not ShowBlood Then Exit;
 If (FlowMode=0)Or(FlowMode=3) Then Exit;
 SetViewPort(VX1,VY1,VX2,VY2,True);
 SetWriteMode(XORPut);
 For V:=1 To NVes Do If VesOn(V)And(Ves[V].PCnt>0) Then Begin
  For J:=Ves[V].PFirst To Ves[V].PFirst+Ves[V].PCnt-1 Do Begin
   U:=PartT[J]*Ves[V].Len;
   K:=Ves[V].First;
   While (K<Ves[V].First+Ves[V].Cnt-2)And(Pts^[K+1].L<U) Do Inc(K);
   Seg:=Pts^[K+1].L-Pts^[K].L;
   If Seg<0.0001 Then T:=0 Else T:=(U-Pts^[K].L)/Seg;
   X:=Psc^[K].X+Round((Psc^[K+1].X-Psc^[K].X)*T);
   Y:=Psc^[K].Y+Round((Psc^[K+1].Y-Psc^[K].Y)*T);
   If ((Psc^[K].R+Psc^[K+1].R) Div 20)>=3 Then H:=3 Else H:=2;
   X:=X-H Div 2; Y:=Y-H Div 2;
   If (X>=0)And(Y>=0)And(X<VW-4)And(Y<VH-4)And(NOld<MaxPart) Then Begin
    SetWriteMode(NormalPut);
    C0:=GetPixel(X+H Div 2,Y+H Div 2);
    SetWriteMode(XORPut);
    If (C0=LightRed)Or(C0=LightBlue)Or(C0=LightMagenta)Or(C0=Yellow)Or
       ((OxyMode=0)And(C0=LightGray)) Then Begin
     Inc(NOld);
     OldPX[NOld]:=X; OldPY[NOld]:=Y; OldPH[NOld]:=H; OldPC[NOld]:=C0 Xor 15;
     XorBlock(X,Y,H,C0 Xor 15);
    End;
   End;
  End;
 End;
 SetWriteMode(NormalPut);
End;

{ Mode 0 : particules seules, 1 : region du coeur, 2 : tout le viewport }
Procedure RenderFrame(Mode:Integer);
Var
 RX1,RY1,RX2,RY2:Integer;
Begin
 HideMouse;
 ProjectAll;
 If Mode=2 Then Begin
  NOld:=0;
  DrawStatic(True,0,0,VW-1,VH-1);
 End
  Else
 Begin
  EraseParticles;
  If Mode=1 Then Begin
   RX1:=MinI(HX1,PHX1)-6; RY1:=MinI(HY1,PHY1)-6;
   RX2:=MaxI(HX2,PHX2)+6; RY2:=MaxI(HY2,PHY2)+6;
   If PHX1>PHX2 Then Begin RX1:=HX1-6; RY1:=HY1-6; RX2:=HX2+6; RY2:=HY2+6; End;
   If RX1<0 Then RX1:=0;
   If RY1<0 Then RY1:=0;
   If RX2>VW-1 Then RX2:=VW-1;
   If RY2>VH-1 Then RY2:=VH-1;
   If (RX2>RX1)And(RY2>RY1) Then DrawStatic(False,RX1,RY1,RX2,RY2);
  End;
 End;
 DrawParticles;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 LastHeartKey:=HeartKey;
 ShowMouse;
End;

{ ====================================================================
  Panneaux : menu, information, trace, etat
  ==================================================================== }

Procedure Panel3D(X1,Y1,X2,Y2:Integer;Fill:Integer);
Begin
 SetFillStyle(SolidFill,Fill);
 Bar(X1,Y1,X2,Y2);
 SetColor(White);
 Line(X1,Y1,X2,Y1); Line(X1,Y1,X1,Y2);
 SetColor(DarkGray);
 Line(X1,Y2,X2,Y2); Line(X2,Y1,X2,Y2);
End;

Procedure PosMenus;
Var
 I,X:Integer;
Begin
 X:=8;
 For I:=1 To NMenu Do Begin
  Menus[I].X:=X;
  Menus[I].W:=Length(Menus[I].Title)*8+16;
  Inc(X,Menus[I].W);
 End;
End;

Procedure DrawMenuBar(Active:Integer);
Var
 I:Integer;
Begin
 SetFillStyle(SolidFill,LightGray);
 Bar(0,0,ScrW-1,MenuH-1);
 SetColor(DarkGray);
 Line(0,MenuH-1,ScrW-1,MenuH-1);
 SetTextStyle(DefaultFont,HorizDir,1);
 For I:=1 To NMenu Do Begin
  If I=Active Then Begin
   SetFillStyle(SolidFill,Blue);
   Bar(Menus[I].X,0,Menus[I].X+Menus[I].W-1,MenuH-2);
   SetColor(White);
  End
   Else
  SetColor(Black);
  OutTextXY(Menus[I].X+8,5,Menus[I].Title);
 End;
End;

Function IsOn(Cmd:Integer):Boolean;
Begin
 IsOn:=False;
 If (Cmd>=cmView)And(Cmd<cmView+8) Then Begin
  Case Cmd-cmView Of
   0:IsOn:=CurView='FULLBODY';
   1:IsOn:=CurView='THORAX';
   2:IsOn:=CurView='HEART';
   3:IsOn:=CurView='LUNGS';
   4:IsOn:=CurView='HEAD';
   5:IsOn:=CurView='ABDOMEN';
   6:IsOn:=CurView='ARMS';
   7:IsOn:=CurView='LEGS';
  End;
 End
  Else
 Case Cmd Of
  cmOrbit:IsOn:=Orbit;
  cmShow:IsOn:=ShowArt;
  cmShow+1:IsOn:=ShowVein;
  cmShow+2:IsOn:=ShowCap;
  cmShow+3:IsOn:=ShowHeart;
  cmShow+4:IsOn:=ShowLung;
  cmShow+5:IsOn:=ShowBody;
  cmShow+6:IsOn:=ShowBlood;
  cmShow+7:IsOn:=ShowLabels;
  cmShow+8:IsOn:=ShowInfo;
  cmShow+9:IsOn:=ShowTrace;
  cmFlow,cmFlow+1,cmFlow+2,cmFlow+3:IsOn:=(FlowMode=Cmd-cmFlow);
  cmOxy,cmOxy+1,cmOxy+2:IsOn:=(OxyMode=Cmd-cmOxy);
  cmVes:IsOn:=ShowSys And ShowPul;
  cmVes+1:IsOn:=ShowSys And Not ShowPul;
  cmVes+2:IsOn:=ShowPul And Not ShowSys;
  cmPlay:IsOn:=Playing;
  cmLoop:IsOn:=Looping;
 End;
End;

Procedure DropGeom(M:Integer;Var X,Y,W,H:Integer);
Var
 I,L,Mx:Integer;
Begin
 Mx:=0;
 For I:=Menus[M].First To Menus[M].First+Menus[M].Cnt-1 Do Begin
  L:=Length(MI[I].Cap)+Length(MI[I].Sc);
  If Length(MI[I].Sc)>0 Then Inc(L,2);
  If L>Mx Then Mx:=L;
 End;
 X:=Menus[M].X; Y:=MenuH;
 W:=Mx*8+36; H:=Menus[M].Cnt*14+6;
 If X+W>ScrW Then X:=ScrW-W;
End;

Procedure DrawDropDown(M,Sel:Integer);
Var
 X,Y,W,H,I,Yi,Ix:Integer;
Begin
 DropGeom(M,X,Y,W,H);
 SetFillStyle(SolidFill,DarkGray);
 Bar(X+3,Y+3,X+W+2,Y+H+2);
 Panel3D(X,Y,X+W-1,Y+H-1,LightGray);
 SetTextStyle(DefaultFont,HorizDir,1);
 For I:=1 To Menus[M].Cnt Do Begin
  Ix:=Menus[M].First+I-1;
  Yi:=Y+3+(I-1)*14;
  If MI[Ix].Cap='-' Then Begin
   SetColor(DarkGray);
   Line(X+4,Yi+6,X+W-5,Yi+6);
   SetColor(White);
   Line(X+4,Yi+7,X+W-5,Yi+7);
  End
   Else
  Begin
   If I=Sel Then Begin
    SetFillStyle(SolidFill,Blue);
    Bar(X+2,Yi,X+W-3,Yi+13);
    SetColor(White);
   End
    Else
   SetColor(Black);
   If IsOn(MI[Ix].Cmd) Then OutTextXY(X+7,Yi+3,'*');
   OutTextXY(X+20,Yi+3,MI[Ix].Cap);
   If MI[Ix].Sc<>'' Then OutTextXY(X+W-8-Length(MI[Ix].Sc)*8,Yi+3,MI[Ix].Sc);
  End;
 End;
End;

Function ItemAt(M:Integer;PX,PY:LongInt):Integer;
Var
 X,Y,W,H:Integer;
 I:Integer;
Begin
 ItemAt:=0;
 DropGeom(M,X,Y,W,H);
 If (PX>=X)And(PX<X+W)And(PY>=Y+3)And(PY<Y+H-3) Then Begin
  I:=(PY-Y-3) Div 14+1;
  If (I>=1)And(I<=Menus[M].Cnt) Then
   If MI[Menus[M].First+I-1].Cap<>'-' Then ItemAt:=I;
 End;
End;

Function TitleAt(PX,PY:LongInt):Integer;
Var
 I:Integer;
Begin
 TitleAt:=0;
 If PY<MenuH Then
  For I:=1 To NMenu Do
   If (PX>=Menus[I].X)And(PX<Menus[I].X+Menus[I].W) Then TitleAt:=I;
End;

Procedure DrawStatus;
Var
 S:String;
Begin
 SetFillStyle(SolidFill,LightGray);
 Bar(0,ScrH-StatH,ScrW-1,ScrH-1);
 SetColor(White);
 Line(0,ScrH-StatH,ScrW-1,ScrH-StatH);
 SetTextStyle(DefaultFont,HorizDir,1);
 SetColor(Black);
 S:=StatusMsg;
 If Length(S)>46 Then S:=Copy(S,1,46);
 OutTextXY(6,ScrH-StatH+5,S);
 S:='Vue '+CurView+'  Zoom '+RealStr(Zoom,1)+'x  '+IntStr(Round(Yaw))+'/'+IntStr(Round(Pitch));
 OutTextXY(ScrW-6-Length(S)*8,ScrH-StatH+5,S);
End;

Procedure InfoLine(Var Y:Integer;S:String;C:Integer);
Begin
 SetColor(C);
 OutTextXY(InfoX+6,Y,S);
 Inc(Y,11);
End;

Procedure DrawInfo;
Var
 Y,I:Integer;
 S:String;
Begin
 If Not ShowInfo Then Exit;
 HideMouse;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 SetFillStyle(SolidFill,Black);
 Bar(InfoX,VY1,ScrW-1,VY2);
 SetColor(LightGray);
 Line(InfoX,VY1,InfoX,VY2);
 SetTextStyle(DefaultFont,HorizDir,1);
 Y:=VY1+6;
 InfoLine(Y,'CIRCULATION',Yellow);
 InfoLine(Y,'Coeur   '+IntStr(HR)+' bpm',White);
 S:=IntStr(Round(PDia+(PSys-PDia)*PresAt(PhaseF)));
 InfoLine(Y,'PA '+S+' ('+IntStr(PSys)+'/'+IntStr(PDia)+')',White);
 InfoLine(Y,'VES     '+IntStr(SV)+' mL',White);
 InfoLine(Y,'Debit   '+RealStr(CardiacOutput,1)+' L/min',White);
 InfoLine(Y,'FE      '+IntStr(Round(100.0*SV/(SV+EsvBase)))+' %',White);
 InfoLine(Y,'VG      '+IntStr(Round(VolAt(PhaseF)))+' mL',White);
 InfoLine(Y,'SpO2 '+IntStr(SatArt)+'/'+IntStr(SatVen)+' %',White);
 Inc(Y,4);
 InfoLine(Y,PhaseName,LightGreen);
 InfoLine(Y,'Temps '+RealStr(SimT,1)+' s',LightGray);
 If Duration>0 Then InfoLine(Y,'Duree '+RealStr(Duration,0)+' s',LightGray);
 If Playing Then S:='Lecture' Else S:='Pause';
 InfoLine(Y,S+'  x'+RealStr(SpeedF,1),LightGray);
 Inc(Y,6);
 InfoLine(Y,'LEGENDE',Yellow);
 If OxyMode=0 Then Begin
  InfoLine(Y,'  Vaisseaux',LightGray);
 End
  Else
 Begin
  SetFillStyle(SolidFill,LightRed); Bar(InfoX+6,Y,InfoX+14,Y+7);
  InfoLine(Y,'   Arteres O2',LightGray);
  SetFillStyle(SolidFill,LightBlue); Bar(InfoX+6,Y,InfoX+14,Y+7);
  InfoLine(Y,'   Veines',LightGray);
  SetFillStyle(SolidFill,LightMagenta); Bar(InfoX+6,Y,InfoX+14,Y+7);
  InfoLine(Y,'   Capillaires',LightGray);
 End;
 Inc(Y,6);
 If Sel>0 Then Begin
  InfoLine(Y,'SELECTION',Yellow);
  S:=Ves[Sel].Name;
  For I:=1 To Length(S) Do If S[I]='_' Then S[I]:=' ';
  InfoLine(Y,Copy(S,1,19),White);
  If Length(S)>19 Then InfoLine(Y,Copy(S,20,19),White);
  Case Ves[Sel].VT Of
   0:S:='Artere';
   1:S:='Veine';
  Else
   S:='Capillaire';
  End;
  If Ves[Sel].Circ=0 Then S:=S+' syst.' Else S:=S+' pulm.';
  InfoLine(Y,S,LightGray);
  InfoLine(Y,'Vit '+RealStr(VelOf(Sel),0)+' cm/s',LightGray);
  InfoLine(Y,'Long '+RealStr(Ves[Sel].Len,0)+' cm',LightGray);
  InfoLine(Y,'O2 '+IntStr(Ves[Sel].SatA)+' > '+IntStr(Ves[Sel].SatB)+' %',LightGray);
 End;
 ShowMouse;
End;

{ ---- Trace ECG et pression ---- }

Function TraceTime(C:Integer):Real;
{ temps de simulation represente par la colonne C }
Var
 D:Integer;
Begin
 D:=TrHead-C;
 If D<0 Then D:=D+TrW;
 TraceTime:=SimT-D*TrWin/TrW;
End;

Procedure TraceY(C:Integer;Var Ye,Yp:Integer);
Var
 Ph:Real;
 I:Integer;
Begin
 Ph:=FracPart(CycleAcc-(SimT-TraceTime(C))*HR/60.0+10.0);
 I:=Trunc(Ph*256) And 255;
 Ye:=TrY+36-Round(EcgTab[I]*28/1000.0);
 Yp:=TrY+80-Round(PresTab[I]*28/1000.0);
End;

Procedure TraceCol(C,Prev:Integer);
Var
 Ye,Yp,Ye0,Yp0,X0:Integer;
Begin
 If Prev>=0 Then X0:=TrLeft+Prev Else X0:=TrLeft+C;
 SetFillStyle(SolidFill,Black);
 Bar(TrLeft+C,TrY+2,TrLeft+C,TrY+TrH-3);
 SetColor(DarkGray);
 Line(TrLeft+C,TrY+36,TrLeft+C,TrY+36);
 Line(TrLeft+C,TrY+80,TrLeft+C,TrY+80);
 TraceY(C,Ye,Yp);
 If Prev>=0 Then TraceY(Prev,Ye0,Yp0) Else Begin Ye0:=Ye; Yp0:=Yp; End;
 SetColor(LightGreen);
 Line(X0,Ye0,TrLeft+C,Ye);
 SetColor(LightRed);
 Line(X0,Yp0,TrLeft+C,Yp);
End;

Procedure DrawTraceFrame;
Begin
 SetFillStyle(SolidFill,Black);
 Bar(0,TrY,ScrW-1,TrY+TrH-1);
 SetColor(LightGray);
 Line(0,TrY,ScrW-1,TrY);
 SetTextStyle(DefaultFont,HorizDir,1);
 SetColor(LightGreen);
 OutTextXY(6,TrY+6,'ECG');
 OutTextXY(6,TrY+16,'II');
 SetColor(LightRed);
 OutTextXY(6,TrY+50,'PA');
 OutTextXY(6,TrY+60,'mmHg');
 SetColor(White);
 OutTextXY(6,TrY+70,IntStr(PSys));
 SetColor(LightGray);
 Line(TrLeft-4,TrY+4,TrLeft-4,TrY+TrH-4);
End;

Procedure DrawTraceFull;
Var
 C,D:Integer;
Begin
 If Not ShowTrace Then Exit;
 HideMouse;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 DrawTraceFrame;
 TrHead:=Trunc(FracPart(SimT/TrWin)*TrW);
 For C:=0 To TrW-1 Do Begin
  D:=(C-TrHead+TrW) Mod TrW;
  If (D>=1)And(D<=6) Then Begin
   SetFillStyle(SolidFill,Black);
   Bar(TrLeft+C,TrY+2,TrLeft+C,TrY+TrH-3);
  End
   Else
  Begin
   If C=0 Then TraceCol(C,-1) Else TraceCol(C,C-1);
  End;
 End;
 ShowMouse;
End;

Procedure DrawTraceStep;
Var
 NewHead,C,P:Integer;
Begin
 If Not ShowTrace Then Exit;
 NewHead:=Trunc(FracPart(SimT/TrWin)*TrW);
 If NewHead=TrHead Then Exit;
 HideMouse;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 C:=TrHead;
 While C<>NewHead Do Begin
  P:=C;
  C:=(C+1) Mod TrW;
  TrHead:=NewHead;
  If C=0 Then TraceCol(C,-1) Else TraceCol(C,P);
  { zone d'effacement devant la tete }
  P:=(C+6) Mod TrW;
  SetFillStyle(SolidFill,Black);
  Bar(TrLeft+P,TrY+2,TrLeft+P,TrY+TrH-3);
 End;
 TrHead:=NewHead;
 ShowMouse;
End;

{ Redessine tout l'ecran }
Procedure RedrawAll;
Begin
 HideMouse;
 Layout;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 SetFillStyle(SolidFill,Black);
 Bar(0,0,ScrW-1,ScrH-1);
 DrawMenuBar(0);
 DrawStatus;
 ShowMouse;
 UpdatePhase;
 If ShowTrace Then DrawTraceFull;
 DrawInfo;
 RenderFrame(2);
 NeedAll:=False; NeedFull:=False; NeedInfo:=False;
End;

{ ====================================================================
  Boites de dialogue
  ==================================================================== }

Procedure DrawBox(X1,Y1,X2,Y2:Integer;Title:String);
Begin
 HideMouse;
 SetViewPort(0,0,ScrW-1,ScrH-1,True);
 SetFillStyle(SolidFill,DarkGray);
 Bar(X1+4,Y1+4,X2+4,Y2+4);
 Panel3D(X1,Y1,X2,Y2,LightGray);
 SetFillStyle(SolidFill,Blue);
 Bar(X1+3,Y1+3,X2-3,Y1+15);
 SetTextStyle(DefaultFont,HorizDir,1);
 SetColor(White);
 OutTextXY(X1+8,Y1+6,Title);
End;

Procedure WaitRelease;
Begin
 Repeat
  GetMouseState(MX,MY,MB);
 Until (MB And 7)=0;
End;

Procedure ShowMsg(Title:String);
Var
 I,W,X1,Y1,X2,Y2,L:Integer;
 Done:Boolean;
 Ch:Char;
Begin
 W:=Length(Title)*8+24;
 For I:=1 To MsgN Do Begin
  L:=Length(MsgLines[I])*8+24;
  If L>W Then W:=L;
 End;
 X1:=(ScrW-W) Div 2; X2:=X1+W;
 Y1:=(ScrH-(MsgN*11+50)) Div 2; Y2:=Y1+MsgN*11+50;
 DrawBox(X1,Y1,X2,Y2,Title);
 SetColor(Black);
 For I:=1 To MsgN Do OutTextXY(X1+12,Y1+24+(I-1)*11,MsgLines[I]);
 Panel3D(X1+W Div 2-30,Y2-24,X1+W Div 2+30,Y2-8,LightGray);
 SetColor(Black);
 OutTextXY(X1+W Div 2-8,Y2-19,'OK');
 ShowMouse;
 WaitRelease;
 Done:=False;
 Repeat
  If KeyPressed Then Begin
   Ch:=ReadKey;
   If Ch=#0 Then Ch:=ReadKey;
   Done:=True;
  End;
  GetMouseState(MX,MY,MB);
  If (MB And 1)<>0 Then Done:=True;
  Delay(5);
 Until Done;
 WaitRelease;
 NeedAll:=True;
End;

Function InputBox(Title,Prompt:String;Var S:String):Boolean;
Var
 Ch:Char;
 Done,Ok:Boolean;
 X1,Y1,X2,Y2:Integer;
 Buf:String;
Begin
 Buf:=S;
 X1:=100; X2:=540; Y1:=190; Y2:=290;
 DrawBox(X1,Y1,X2,Y2,Title);
 SetColor(Black);
 OutTextXY(X1+12,Y1+26,Prompt);
 SetColor(Black);
 OutTextXY(X1+12,Y2-22,'Entree = valider    Echap = annuler');
 ShowMouse;
 Done:=False; Ok:=False;
 Repeat
  HideMouse;
  SetFillStyle(SolidFill,White);
  Bar(X1+12,Y1+46,X2-12,Y1+62);
  SetColor(Black);
  Rectangle(X1+12,Y1+46,X2-12,Y1+62);
  OutTextXY(X1+16,Y1+51,Buf+'_');
  ShowMouse;
  Ch:=ReadKey;
  If Ch=#0 Then Ch:=ReadKey Else
  If Ch=#13 Then Begin Ok:=True; Done:=True; End Else
  If Ch=#27 Then Done:=True Else
  If Ch=#8 Then Begin
   If Length(Buf)>0 Then Delete(Buf,Length(Buf),1);
  End
   Else
  If (Ch>=' ')And(Length(Buf)<48) Then Buf:=Buf+Ch;
 Until Done;
 If Ok Then S:=TrimStr(Buf);
 InputBox:=Ok And (S<>'');
 NeedAll:=True;
End;

Function Confirm(Msg:String):Boolean;
Var
 Ch:Char;
 X1,Y1,X2,Y2:Integer;
Begin
 Ch:=' ';
 X1:=150; X2:=490; Y1:=200; Y2:=270;
 DrawBox(X1,Y1,X2,Y2,'Confirmation');
 SetColor(Black);
 OutTextXY(X1+14,Y1+28,Msg);
 OutTextXY(X1+14,Y1+46,'O = Oui      N = Non');
 ShowMouse;
 Repeat
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   Ch:=ReadKey;
   Ch:=#1;
  End;
  Ch:=UpCase(Ch);
 Until (Ch='O')Or(Ch='Y')Or(Ch='N')Or(Ch=#27)Or(Ch=#13);
 Confirm:=(Ch='O')Or(Ch='Y')Or(Ch=#13);
 NeedAll:=True;
End;

{ ====================================================================
  Exportation
  ==================================================================== }

Procedure ExportSim(Fn:String;Fmt:Integer);
Var
 T:Text;
 I,N,J:Integer;
 Tm,F,Fl,P:Real;
 Dur:Real;
Begin
 Assign(T,Fn);
 {$I-}Rewrite(T);{$I+}
 If IOResult<>0 Then Begin
  Warn('Impossible de creer : '+Fn);
  Exit;
 End;
 If Fmt=2 Then Begin
  WriteLn(T,'# CS3DA - export du modele ',ModelName);
  WriteLn(T,'o CS3DA');
  For I:=1 To NV Do
   WriteLn(T,'v ',Vtx^[I].X:0:3,' ',Vtx^[I].Y:0:3,' ',Vtx^[I].Z:0:3);
  For I:=1 To NPts Do
   WriteLn(T,'v ',Pts^[I].X:0:3,' ',Pts^[I].Y:0:3,' ',Pts^[I].Z:0:3);
  For J:=1 To NS Do Begin
   WriteLn(T,'g ',Structs[J].Name);
   For I:=1 To NF Do If Faces^[I].S=J Then Begin
    Write(T,'f');
    For N:=1 To Faces^[I].N Do Write(T,' ',Faces^[I].V[N]);
    WriteLn(T);
   End;
  End;
  For J:=1 To NVes Do Begin
   WriteLn(T,'g ',Ves[J].Name);
   Write(T,'l');
   For I:=Ves[J].First To Ves[J].First+Ves[J].Cnt-1 Do Write(T,' ',NV+I);
   WriteLn(T);
  End;
 End
  Else
 Begin
  Dur:=Duration;
  If Dur<=0 Then Dur:=10;
  If Fmt=1 Then Begin
   WriteLn(T,'CS3DA - donnees de simulation');
   WriteLn(T,'Frequence cardiaque : ',HR,' bpm');
   WriteLn(T,'Pression           : ',PSys,'/',PDia,' mmHg');
   WriteLn(T,'Volume d''ejection  : ',SV,' mL');
   WriteLn(T,'Debit cardiaque    : ',CardiacOutput:0:2,' L/min');
   WriteLn(T,'Duree              : ',Dur:0:1,' s');
   WriteLn(T);
   WriteLn(T,'  temps    phase     ECG    PA(mmHg)   VG(mL)  debit(L/min)');
  End
   Else
  WriteLn(T,'temps_s,phase,ecg_mv,pression_mmHg,volume_vg_ml,debit_aortique_l_min');
  N:=Trunc(Dur*50);
  For I:=0 To N Do Begin
   Tm:=I*0.02;
   F:=FracPart(Tm*HR/60.0);
   P:=PDia+(PSys-PDia)*PresAt(F);
   Fl:=(VolAt(FracPart(F-0.002+1))-VolAt(FracPart(F+0.002)))/(0.004*60.0/HR)*0.06;
   If Fl<0 Then Fl:=0;
   If Fmt=1 Then
    WriteLn(T,Tm:8:2,F:9:3,EcgAt(F):9:3,P:10:1,VolAt(F):10:1,Fl:11:2)
   Else
    WriteLn(T,Tm:0:2,',',F:0:4,',',EcgAt(F):0:4,',',P:0:1,',',VolAt(F):0:1,',',Fl:0:2);
  End;
 End;
 Close(T);
 If GfxOn Then SetStatus('Exporte : '+Fn) Else Info('Exporte : '+Fn);
End;

Function FormatOf(Fn:String):Integer;
Var
 E:String;
Begin
 E:=UpStr(FmtName);
 If E='' Then E:=UpStr(Copy(Fn,Length(Fn)-2,3));
 If E='TXT' Then FormatOf:=1 Else
 If E='OBJ' Then FormatOf:=2 Else FormatOf:=0;
End;

{ ====================================================================
  Commandes
  ==================================================================== }

Procedure SetHR(V:Integer);
Begin
 If V<30 Then V:=30;
 If V>220 Then V:=220;
 HR:=V;
 SetStatus('Frequence cardiaque : '+IntStr(HR)+' bpm');
 NeedInfo:=True;
End;

Procedure SetPressure(V:Integer);
Begin
 If V<70 Then V:=70;
 If V>240 Then V:=240;
 PDia:=Round(PDia*V/PSys);
 PSys:=V;
 SetStatus('Pression : '+IntStr(PSys)+'/'+IntStr(PDia)+' mmHg');
 NeedInfo:=True;
End;

Procedure SetSpeed(V:Real);
Begin
 If V<0.1 Then V:=0.1;
 If V>10 Then V:=10;
 SpeedF:=V;
 SetStatus('Vitesse : x'+RealStr(SpeedF,2));
 NeedInfo:=True;
End;

Procedure SetFPS(V:Integer);
Begin
 If V<1 Then V:=1;
 If V>60 Then V:=60;
 FPS:=V;
 SetStatus('Images par seconde : '+IntStr(FPS));
End;

Procedure StopAnim;
Begin
 Playing:=False;
 SimT:=0; CycleAcc:=0;
 ResetParticles;
 NeedAll:=True;
 SetStatus('Animation arretee');
End;

Procedure ToggleFlow;
Begin
 FlowMode:=(FlowMode+1) Mod 4;
 NeedFull:=True;
End;

Procedure DoCommand(Cmd:Integer);
Var
 S:String;
 Names:Array[0..7] Of String[12];
Begin
 Names[0]:='FULLBODY'; Names[1]:='THORAX'; Names[2]:='HEART'; Names[3]:='LUNGS';
 Names[4]:='HEAD'; Names[5]:='ABDOMEN'; Names[6]:='ARMS'; Names[7]:='LEGS';
 If (Cmd>=cmView)And(Cmd<cmView+8) Then Begin
  If ApplyView(Names[Cmd-cmView]) Then SetStatus('Vue : '+CurView);
 End
  Else
 If (Cmd>=cmCam)And(Cmd<cmCam+7) Then Begin
  CamIdx:=Cmd-cmCam;
  Case Cmd-cmCam Of
   0:SetCamera('FRONT');
   1:SetCamera('BACK');
   2:SetCamera('LEFT');
   3:SetCamera('RIGHT');
   4:SetCamera('TOP');
   5:SetCamera('BOTTOM');
   6:SetCamera('ISO');
  End;
 End
  Else
 If (Cmd>=cmProf)And(Cmd<cmProf+MaxProf) Then Begin
  If Cmd-cmProf+1<=NProf Then Begin
   ApplyProfile(Profs[Cmd-cmProf+1].Name);
   SetStatus('Profil : '+Profs[Cmd-cmProf+1].Name);
   NeedAll:=True;
  End;
 End
  Else
 Case Cmd Of
  cmQuit:If Confirm('Quitter CS3DA ?') Then Quit:=True;
  cmLoad:Begin
   S:=ModelFile;
   If InputBox('Charger un modele','Nom du fichier (.C3D ou .OBJ) :',S) Then Begin
    If LoadModel(S,False) Then Begin
     ModelFile:=S; ApplyView('FULLBODY'); SetStatus('Modele charge : '+S);
    End
     Else
    SetStatus('Echec du chargement : '+S);
   End;
   NeedAll:=True;
  End;
  cmImport:Begin
   S:='';
   If InputBox('Importer des donnees','Nom du fichier a fusionner :',S) Then Begin
    If LoadModel(S,True) Then SetStatus('Donnees importees : '+S)
     Else SetStatus('Echec de l''importation : '+S);
   End;
   NeedAll:=True;
  End;
  cmExpCSV:ExportSim('CS3DA.CSV',0);
  cmExpTXT:ExportSim('CS3DA.TXT',1);
  cmExpOBJ:ExportSim('CS3DA.OBJ',2);
  cmOrbit:Begin Orbit:=Not Orbit; NeedFull:=True; End;
  cmZoomIn:Begin Zoom:=Zoom*1.2; If Zoom>20 Then Zoom:=20; NeedFull:=True; End;
  cmZoomOut:Begin Zoom:=Zoom/1.2; If Zoom<0.2 Then Zoom:=0.2; NeedFull:=True; End;
  cmCamReset:Begin Yaw:=0; Pitch:=0; Orbit:=False; ApplyView('FULLBODY'); End;
  cmShow:Begin ShowArt:=Not ShowArt; NeedAll:=True; End;
  cmShow+1:Begin ShowVein:=Not ShowVein; NeedAll:=True; End;
  cmShow+2:Begin ShowCap:=Not ShowCap; NeedAll:=True; End;
  cmShow+3:Begin ShowHeart:=Not ShowHeart; NeedAll:=True; End;
  cmShow+4:Begin ShowLung:=Not ShowLung; NeedAll:=True; End;
  cmShow+5:Begin ShowBody:=Not ShowBody; NeedAll:=True; End;
  cmShow+6:Begin ShowBlood:=Not ShowBlood; NeedAll:=True; End;
  cmShow+7:Begin ShowLabels:=Not ShowLabels; NeedAll:=True; End;
  cmShow+8:Begin ShowInfo:=Not ShowInfo; NeedAll:=True; End;
  cmShow+9:Begin ShowTrace:=Not ShowTrace; NeedAll:=True; End;
  cmFlow,cmFlow+1,cmFlow+2,cmFlow+3:Begin FlowMode:=Cmd-cmFlow; NeedAll:=True; End;
  cmOxy,cmOxy+1,cmOxy+2:Begin OxyMode:=Cmd-cmOxy; NeedAll:=True; End;
  cmVes:Begin ShowSys:=True; ShowPul:=True; NeedAll:=True; End;
  cmVes+1:Begin ShowSys:=True; ShowPul:=False; NeedAll:=True; End;
  cmVes+2:Begin ShowSys:=False; ShowPul:=True; NeedAll:=True; End;
  cmHRUp:SetHR(HR+5);
  cmHRDn:SetHR(HR-5);
  cmPrUp:SetPressure(PSys+5);
  cmPrDn:SetPressure(PSys-5);
  cmPlay:Begin
   Playing:=Not Playing;
   If Playing Then SetStatus('Lecture') Else SetStatus('Pause');
   NeedInfo:=True;
  End;
  cmStop:StopAnim;
  cmLoop:Begin Looping:=Not Looping; NeedInfo:=True; End;
  cmSpdUp:SetSpeed(SpeedF*1.25);
  cmSpdDn:SetSpeed(SpeedF/1.25);
  cmFpsUp:SetFPS(FPS+5);
  cmFpsDn:SetFPS(FPS-5);
  cmKeys:Begin
   MsgN:=14;
   MsgLines[1]:='Espace  Lecture / pause        S  Arret';
   MsgLines[2]:='L       Boucle                  O  Orbite automatique';
   MsgLines[3]:='Fleches Rotation                +/- Zoom (PgUp/PgDn)';
   MsgLines[4]:='1..8    Vues anatomiques        C  Camera suivante';
   MsgLines[5]:='R       Reinitialiser la camera F  Mode de flux';
   MsgLines[6]:='X       Mode d''oxygenation      B  Sang (particules)';
   MsgLines[7]:='T       Etiquettes              I  Panneau d''info';
   MsgLines[8]:='E       Trace ECG               Tab  Vaisseau suivant';
   MsgLines[9]:='[ ]     Frequence cardiaque -/+ < >  Vitesse -/+';
   MsgLines[10]:='F10     Menus                   Echap  Quitter';
   MsgLines[11]:='';
   MsgLines[12]:='Souris : bouton gauche = rotation, bouton droit =';
   MsgLines[13]:='deplacement, clic sur un vaisseau = selection.';
   MsgLines[14]:='';
   ShowMsg('Raccourcis clavier');
  End;
  cmAbout:Begin
   MsgN:=6;
   MsgLines[1]:='CS3DA '+AppVersion+' - Circulatory System 3D Anatomy';
   MsgLines[2]:='Clone ecrit en Turbo Pascal / Free Pascal';
   MsgLines[3]:='Modele : '+ModelName;
   MsgLines[4]:=IntStr(NV)+' sommets, '+IntStr(NF)+' faces, '+IntStr(NVes)+' vaisseaux';
   MsgLines[5]:='';
   MsgLines[6]:='https://www.gladir.com/biologie-0';
   ShowMsg('A propos');
  End;
 End;
 NeedInfo:=True;
End;

{ ---- Construction des menus ---- }

Procedure AddMenu(T:String);
Begin
 Inc(NMenu);
 Menus[NMenu].Title:=T;
 Menus[NMenu].First:=NMI+1;
 Menus[NMenu].Cnt:=0;
End;

Procedure AddItem(Cap,Sc:String;Cmd:Integer);
Begin
 Inc(NMI);
 MI[NMI].Cap:=Cap; MI[NMI].Sc:=Sc; MI[NMI].Cmd:=Cmd;
 Inc(Menus[NMenu].Cnt);
End;

Procedure BuildMenus;
Var
 I:Integer;
Begin
 NMenu:=0; NMI:=0;
 AddMenu('Fichier');
 AddItem('Charger un modele...','',cmLoad);
 AddItem('Importer des donnees...','',cmImport);
 AddItem('-','',0);
 AddItem('Exporter simulation CSV','',cmExpCSV);
 AddItem('Exporter simulation TXT','',cmExpTXT);
 AddItem('Exporter geometrie OBJ','',cmExpOBJ);
 AddItem('-','',0);
 AddItem('Quitter','Echap',cmQuit);
 AddMenu('Vue');
 AddItem('Corps entier','1',cmView);
 AddItem('Thorax','2',cmView+1);
 AddItem('Coeur','3',cmView+2);
 AddItem('Poumons','4',cmView+3);
 AddItem('Tete','5',cmView+4);
 AddItem('Abdomen','6',cmView+5);
 AddItem('Bras','7',cmView+6);
 AddItem('Jambes','8',cmView+7);
 AddMenu('Camera');
 AddItem('Face','',cmCam);
 AddItem('Dos','',cmCam+1);
 AddItem('Gauche','',cmCam+2);
 AddItem('Droite','',cmCam+3);
 AddItem('Dessus','',cmCam+4);
 AddItem('Dessous','',cmCam+5);
 AddItem('Isometrique','',cmCam+6);
 AddItem('-','',0);
 AddItem('Orbite automatique','O',cmOrbit);
 AddItem('Zoom avant','+',cmZoomIn);
 AddItem('Zoom arriere','-',cmZoomOut);
 AddItem('Reinitialiser','R',cmCamReset);
 AddMenu('Structures');
 AddItem('Arteres','',cmShow);
 AddItem('Veines','',cmShow+1);
 AddItem('Capillaires','',cmShow+2);
 AddItem('Coeur','',cmShow+3);
 AddItem('Poumons','',cmShow+4);
 AddItem('Corps (silhouette)','',cmShow+5);
 AddItem('-','',0);
 AddItem('Sang (particules)','B',cmShow+6);
 AddItem('Etiquettes','T',cmShow+7);
 AddItem('Panneau d''information','I',cmShow+8);
 AddItem('Trace ECG / pression','E',cmShow+9);
 AddMenu('Circulation');
 AddItem('Flux : aucun','',cmFlow);
 AddItem('Flux : anime','F',cmFlow+1);
 AddItem('Flux : pulsatile','',cmFlow+2);
 AddItem('Flux : fleches','',cmFlow+3);
 AddItem('-','',0);
 AddItem('Oxygene : aucun','X',cmOxy);
 AddItem('Oxygene : couleur','',cmOxy+1);
 AddItem('Oxygene : gradient','',cmOxy+2);
 AddItem('-','',0);
 AddItem('Tous les vaisseaux','',cmVes);
 AddItem('Circulation systemique','',cmVes+1);
 AddItem('Circulation pulmonaire','',cmVes+2);
 AddMenu('Physio');
 AddItem('Frequence +5 bpm',']',cmHRUp);
 AddItem('Frequence -5 bpm','[',cmHRDn);
 AddItem('Pression +5 mmHg','',cmPrUp);
 AddItem('Pression -5 mmHg','',cmPrDn);
 AddItem('-','',0);
 For I:=1 To NProf Do AddItem('Profil '+Profs[I].Name,'',cmProf+I-1);
 AddMenu('Animation');
 AddItem('Lecture / pause','Espace',cmPlay);
 AddItem('Arret','S',cmStop);
 AddItem('Boucle','L',cmLoop);
 AddItem('-','',0);
 AddItem('Vitesse +','>',cmSpdUp);
 AddItem('Vitesse -','<',cmSpdDn);
 AddItem('Images/s +','',cmFpsUp);
 AddItem('Images/s -','',cmFpsDn);
 AddMenu('Aide');
 AddItem('Raccourcis clavier','F1',cmKeys);
 AddItem('A propos de CS3DA','',cmAbout);
 PosMenus;
End;

{ ---- Boucle d'un menu deroulant (souris et clavier) ---- }

Function FirstSel(M,Start,Dir:Integer):Integer;
Var
 I,N:Integer;
Begin
 N:=Menus[M].Cnt;
 I:=Start;
 If I<1 Then I:=N;
 If I>N Then I:=1;
 While MI[Menus[M].First+I-1].Cap='-' Do Begin
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
 End;
 FirstSel:=I;
End;

Function RunMenu(Start:Integer):Integer;
Var
 M,Sl,Hit,HM,Res:Integer;
 Done,NewM,Moved:Boolean;
 Ch:Char;
 PB,LX,LY:LongInt;
Begin
 M:=Start; Res:=0; Done:=False; NewM:=True; Sl:=1;
 WaitRelease;
 PB:=0; LX:=-1; LY:=-1;
 Repeat
  If NewM Then Begin
   RedrawAll;
   HideMouse;
   DrawMenuBar(M);
   Sl:=FirstSel(M,1,1);
   DrawDropDown(M,Sl);
   ShowMouse;
   NewM:=False;
  End;
  GetMouseState(MX,MY,MB);
  Moved:=(MX<>LX)Or(MY<>LY);
  If Moved Then Begin
   {$IFDEF FPC}
   HideMouse; ShowMouse;
   {$ENDIF}
   LX:=MX; LY:=MY;
   Hit:=ItemAt(M,MX,MY);
   If (Hit>0)And(Hit<>Sl) Then Begin
    Sl:=Hit;
    HideMouse; DrawDropDown(M,Sl); ShowMouse;
   End;
  End;
  If ((MB And 1)<>0)And((PB And 1)=0) Then Begin
   Hit:=ItemAt(M,MX,MY);
   If Hit>0 Then Begin
    Res:=MI[Menus[M].First+Hit-1].Cmd;
    Done:=True;
   End
    Else
   Begin
    HM:=TitleAt(MX,MY);
    If (HM>0)And(HM<>M) Then Begin M:=HM; NewM:=True; End
     Else Done:=True;
   End;
  End;
  PB:=MB;
  If KeyPressed Then Begin
   Ch:=ReadKey;
   If Ch=#0 Then Begin
    Ch:=ReadKey;
    Case Ord(Ch) Of
     72:Begin Sl:=FirstSel(M,Sl-1,-1); HideMouse; DrawDropDown(M,Sl); ShowMouse; End;
     80:Begin Sl:=FirstSel(M,Sl+1,1); HideMouse; DrawDropDown(M,Sl); ShowMouse; End;
     75:Begin Dec(M); If M<1 Then M:=NMenu; NewM:=True; End;
     77:Begin Inc(M); If M>NMenu Then M:=1; NewM:=True; End;
    End;
   End
    Else
   If Ch=#27 Then Done:=True Else
   If Ch=#13 Then Begin
    Res:=MI[Menus[M].First+Sl-1].Cmd;
    Done:=True;
   End;
  End;
  Delay(5);
 Until Done;
 WaitRelease;
 NeedAll:=True;
 RunMenu:=Res;
End;

{ ====================================================================
  Selection d'un vaisseau a la souris
  ==================================================================== }

Procedure PickVessel(PX,PY:Integer);
Var
 V,K,Best:Integer;
 BD,D,Dx,Dy,L2,T,Qx,Qy,Rr:Real;
Begin
 Best:=0; BD:=1E9;
 For V:=1 To NVes Do If VesOn(V) Then
  For K:=Ves[V].First To Ves[V].First+Ves[V].Cnt-2 Do Begin
   Dx:=Psc^[K+1].X-Psc^[K].X; Dy:=Psc^[K+1].Y-Psc^[K].Y;
   L2:=Dx*Dx+Dy*Dy;
   If L2<0.01 Then T:=0 Else T:=((PX-Psc^[K].X)*Dx+(PY-Psc^[K].Y)*Dy)/L2;
   If T<0 Then T:=0;
   If T>1 Then T:=1;
   Qx:=Psc^[K].X+T*Dx; Qy:=Psc^[K].Y+T*Dy;
   D:=Sqrt(Sqr(PX-Qx)+Sqr(PY-Qy));
   Rr:=(Psc^[K].R+Psc^[K+1].R)/20+3;
   If (D<=Rr)And(D<BD) Then Begin BD:=D; Best:=V; End;
  End;
 If Best<>Sel Then Begin
  Sel:=Best;
  If Sel>0 Then SetStatus(Ves[Sel].Name) Else SetStatus('Aucune selection');
  NeedFull:=True; NeedInfo:=True;
 End;
End;

Procedure NextVessel;
Var
 I:Integer;
Begin
 If NVes=0 Then Exit;
 I:=Sel;
 Repeat
  Inc(I);
  If I>NVes Then I:=0;
 Until (I=0)Or VesOn(I)Or(I=Sel);
 Sel:=I;
 If Sel>0 Then SetStatus(Ves[Sel].Name) Else SetStatus('Aucune selection');
 NeedFull:=True; NeedInfo:=True;
End;

{ ====================================================================
  Boucle principale
  ==================================================================== }

Procedure HandleKey;
Var
 Ch:Char;
 K:Integer;
Begin
 K:=0;
 Ch:=ReadKey;
 If Ch=#0 Then Begin
  Ch:=ReadKey;
  Case Ord(Ch) Of
   75:Begin Yaw:=Yaw-5; Orbit:=False; NeedFull:=True; End;
   77:Begin Yaw:=Yaw+5; Orbit:=False; NeedFull:=True; End;
   72:Begin Pitch:=Pitch+5; If Pitch>90 Then Pitch:=90; NeedFull:=True; End;
   80:Begin Pitch:=Pitch-5; If Pitch<-90 Then Pitch:=-90; NeedFull:=True; End;
   73:DoCommand(cmZoomIn);
   81:DoCommand(cmZoomOut);
   59:DoCommand(cmKeys);
   68:Begin K:=RunMenu(1); If K<>0 Then DoCommand(K); End;
   45:Quit:=True;
  End;
 End
  Else
 Begin
  Case UpCase(Ch) Of
   #27:DoCommand(cmQuit);
   ' ':DoCommand(cmPlay);
   'S':StopAnim;
   'L':DoCommand(cmLoop);
   'O':DoCommand(cmOrbit);
   '+','=':DoCommand(cmZoomIn);
   '-':DoCommand(cmZoomOut);
   'R':DoCommand(cmCamReset);
   'C':Begin
        CamIdx:=(CamIdx+1) Mod 7;
        DoCommand(cmCam+CamIdx);
       End;
   'F':Begin
        ToggleFlow;
        Case FlowMode Of
         0:SetStatus('Flux : aucun');
         1:SetStatus('Flux : anime');
         2:SetStatus('Flux : pulsatile');
        Else
         SetStatus('Flux : fleches');
        End;
        NeedInfo:=True;
       End;
   'X':Begin OxyMode:=(OxyMode+1) Mod 3; NeedAll:=True; End;
   'B':DoCommand(cmShow+6);
   'T':DoCommand(cmShow+7);
   'I':DoCommand(cmShow+8);
   'E':DoCommand(cmShow+9);
   '[':DoCommand(cmHRDn);
   ']':DoCommand(cmHRUp);
   '<',',':DoCommand(cmSpdDn);
   '>','.':DoCommand(cmSpdUp);
   #9:NextVessel;
   '1'..'8':DoCommand(cmView+Ord(Ch)-Ord('1'));
  End;
 End;
End;

Procedure MainLoop;
Var
 LastT,T1,FrameT,D:LongInt;
 Dt,Ds:Real;
 PB,LX,LY,DownX,DownY:LongInt;
 Dragging,Moved:Boolean;
 M,Cmd,Mode:Integer;
 AnyMotion:Boolean;
Begin
 LastT:=Ticks; FrameT:=LastT;
 PB:=0; LX:=-1; LY:=-1; DownX:=0; DownY:=0; Dragging:=False; Moved:=False;
 RedrawAll;
 Repeat
  { ---- temps ---- }
  T1:=Ticks;
  D:=T1-LastT;
  If D<0 Then D:=D+8640000;
  Dt:=0;
  If D>0 Then Begin
   Dt:=D/100.0;
   If Dt>0.25 Then Dt:=0.25;
   LastT:=T1;
  End;
  { ---- souris ---- }
  GetMouseState(MX,MY,MB);
  If (MX<>LX)Or(MY<>LY) Then Begin
   {$IFDEF FPC}
   HideMouse; ShowMouse;
   {$ENDIF}
  End;
  If ((MB And 1)<>0)And((PB And 1)=0) Then Begin
   M:=TitleAt(MX,MY);
   If M>0 Then Begin
    Cmd:=RunMenu(M);
    If Cmd<>0 Then DoCommand(Cmd);
    LastT:=Ticks;
   End
    Else
   Begin
    If (MX>=VX1)And(MX<=VX2)And(MY>=VY1)And(MY<=VY2) Then Begin
     Dragging:=True; Moved:=False; DownX:=MX; DownY:=MY;
    End;
   End;
  End;
  If Dragging And ((MB And 1)<>0) Then Begin
   If (Abs(MX-LX)+Abs(MY-LY)>0)And(LX>=0) Then Begin
    If Abs(MX-DownX)+Abs(MY-DownY)>3 Then Moved:=True;
    If Moved Then Begin
     Yaw:=Yaw+(MX-LX)*0.6;
     Pitch:=Pitch+(MY-LY)*0.6;
     If Pitch>90 Then Pitch:=90;
     If Pitch<-90 Then Pitch:=-90;
     Orbit:=False;
     NeedFull:=True;
    End;
   End;
  End;
  If Dragging And ((MB And 1)=0) Then Begin
   If Not Moved Then Begin
    If (MX>=VX1)And(MX<=VX2)And(MY>=VY1)And(MY<=VY2) Then PickVessel(MX-VX1,MY-VY1);
   End;
   Dragging:=False;
  End;
  If ((MB And 2)<>0)And(LX>=0)And((PB And 2)<>0) Then Begin
   If (MX<>LX)Or(MY<>LY) Then Begin
    OffX:=OffX+(MX-LX); OffY:=OffY+(MY-LY);
    NeedFull:=True;
   End;
  End;
  PB:=MB; LX:=MX; LY:=MY;
  { ---- clavier ---- }
  While KeyPressed And Not Quit Do HandleKey;
  { ---- simulation ---- }
  If Playing And (Dt>0) Then Begin
   Ds:=Dt*SpeedF;
   SimT:=SimT+Ds;
   CycleAcc:=CycleAcc+Ds*HR/60.0;
   StepParticles(Ds);
   If (Duration>0)And(SimT>=Duration) Then Begin
    If Looping Then SimT:=SimT-Duration Else Begin
     SimT:=Duration; Playing:=False; SetStatus('Simulation terminee');
     NeedInfo:=True;
    End;
   End;
  End;
  If Orbit And (Dt>0) Then Begin
   Yaw:=Yaw+Dt*25;
   NeedFull:=True;
  End;
  If Yaw>180 Then Yaw:=Yaw-360;
  If Yaw<-180 Then Yaw:=Yaw+360;
  { ---- dessin ---- }
  UpdatePhase;
  AnyMotion:=Playing And ShowBlood And (FlowMode In [1,2]);
  If NeedAll Then Begin
   RedrawAll;
  End
   Else
  Begin
   Mode:=-1;
   If NeedFull Then Mode:=2 Else
   If HeartKey<>LastHeartKey Then Mode:=1 Else
   If AnyMotion And (Dt>0) Then Mode:=0;
   If Mode>=0 Then RenderFrame(Mode);
   NeedFull:=False;
   If NeedInfo Or (Playing And (T1-LastInfo>=25)) Or (T1<LastInfo) Then Begin
    DrawInfo;
    HideMouse; DrawStatus; ShowMouse;
    LastInfo:=T1;
    NeedInfo:=False;
   End;
   If Playing And (Dt>0) Then DrawTraceStep;
  End;
  { ---- limiteur d'images par seconde ---- }
  Repeat
   Delay(1);
   D:=Ticks-FrameT;
   If D<0 Then D:=D+8640000;
  Until D>=100 Div FPS;
  FrameT:=Ticks;
 Until Quit;
End;

{ ====================================================================
  Ligne de commande
  ==================================================================== }

Procedure ShowHelp;
Begin
 WriteLn('CS3DA ',AppVersion,' - Circulatory System 3D Anatomy (reseau sanguin)');
 WriteLn;
 WriteLn('Syntaxe : CS3DA [options]');
 WriteLn;
 WriteLn('/?                   Affiche l''aide de cette commande');
 WriteLn('  /HELP              Affiche l''aide de cette commande');
 WriteLn('  /VERSION           Affiche la version de cette commande');
 WriteLn('  /CONFIG:<file>     Charge le fichier de configuration');
 WriteLn('  /PROFILE:<name>    Charge le profile de simulation');
 WriteLn('  /LOG:<file>        Ecrire un journal de diagnostique');
 WriteLn('  /QUIET             Suppression de messages informationnel');
 WriteLn;
 WriteLn('Visualisation:');
 WriteLn('  /VIEW:<mode>       Fixe la vue anatomique');
 WriteLn('  /MODEL:<file>      Charge un modele anatomique 3D');
 WriteLn('  /SHOW:<elements>   Affiche les structures selectionnees');
 WriteLn('  /HIDE:<elements>   Cache les structures selectionnees');
 WriteLn('  /CAMERA:<mode>     Fixe la position de la camera');
 WriteLn('  /ZOOM:<value>      Fixe le zoom initiale');
 WriteLn('  /BACKGROUND:<name> Fixe l''arriere-plan');
 WriteLn;
 WriteLn('Circulation:');
 WriteLn('  /HEART:<bpm>       Definir la frequence cardiaque (battements par minute)');
 WriteLn('  /FLOW:<mode>       Configurer la visualisation du flux sanguin');
 WriteLn('  /OXYGEN:<mode>     Configurer l''affichage de l''oxygenation');
 WriteLn('  /VESSELS:<type>    Selectionner les types de vaisseaux');
 WriteLn('  /PRESSURE:<value>  Definir la pression de simulation');
 WriteLn('  /SPEED:<value>     Definir la vitesse d''animation');
 WriteLn;
 WriteLn('Animation:');
 WriteLn('  /PLAY              Lancer l''animation');
 WriteLn('  /PAUSE             Pause animation');
 WriteLn('  /STOP              Arrete l''animation');
 WriteLn('  /LOOP              Repeter l''animation');
 WriteLn('  /DURATION:<sec>    Definir la duree de la simulation');
 WriteLn('  /FPS:<value>       Definir la frequence d''images de l''animation');
 WriteLn;
 WriteLn('Donnees:');
 WriteLn('  /IMPORT:<file>     Importer des donnees anatomiques');
 WriteLn('  /EXPORT:<file>     Exporter les donnees de simulation (puis quitter)');
 WriteLn('  /FORMAT:<type>     Definir le format d''exportation (CSV, TXT, OBJ)');
 WriteLn;
 WriteLn('Exemples:');
 WriteLn('  CS3DA /VIEW:FULLBODY /PLAY');
 WriteLn('  CS3DA /HEART:72 /FLOW:ANIMATED /PLAY');
 WriteLn('  CS3DA /SHOW:ARTERIES,VEINS,CAPILLARIES');
 WriteLn('  CS3DA /MODEL:human.c3d /CAMERA:FRONT');
 WriteLn('  CS3DA /HEART:90 /SPEED:1.5 /DURATION:60');
 WriteLn;
 WriteLn('Valeurs :');
 WriteLn('  VIEW       FULLBODY THORAX HEART LUNGS HEAD ABDOMEN ARMS LEGS');
 WriteLn('  CAMERA     FRONT BACK LEFT RIGHT TOP BOTTOM ISO ORBIT');
 WriteLn('  SHOW/HIDE  ARTERIES VEINS CAPILLARIES HEART LUNGS BODY BLOOD LABELS INFO ECG ALL');
 WriteLn('  FLOW       OFF ANIMATED PULSATILE ARROWS');
 WriteLn('  OXYGEN     OFF COLOR GRADIENT');
 WriteLn('  VESSELS    ALL ARTERIES VEINS CAPILLARIES SYSTEMIC PULMONARY');
 WriteLn('  BACKGROUND BLACK BLUE GRAY WHITE GRID (ou un nom de couleur BGI)');
 WriteLn('  PROFILE    voir SAMPLES\CS3DA\PHYSIO.CFG (REST, SLEEP, EXERCISE, ...)');
 WriteLn('  Sans /PLAY, /PAUSE ni /STOP, l''animation demarre automatiquement.');
 WriteLn('  Le premier /SHOW n''affiche que les structures listees.');
 Halt(0);
End;

Procedure ParseOption(Arg:String);Forward;

Procedure ReadConfigFile(Fn:String);
Var
 T:Text;
 Path,L:String;
Begin
 Path:=FindFile(Fn);
 If Path='' Then Begin
  Warn('Fichier de configuration introuvable : '+Fn);
  Exit;
 End;
 Assign(T,Path);
 {$I-}Reset(T);{$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(T) Do Begin
  ReadLn(T,L);
  L:=TrimStr(L);
  If (L<>'')And(L[1]<>';')And(L[1]<>'#') Then ParseOption(L);
 End;
 Close(T);
End;

Procedure ParseOption(Arg:String);
Var
 Nm,Vl,U:String;
 P,P2,C:Integer;
 R:Real;
Begin
 Arg:=TrimStr(Arg);
 If Arg='' Then Exit;
 If (Arg[1]='/')Or(Arg[1]='-') Then Delete(Arg,1,1);
 If (Arg<>'')And(Arg[1]='-') Then Delete(Arg,1,1);
 If Arg='' Then Exit;
 P:=Pos(':',Arg); P2:=Pos('=',Arg);
 If (P2>0)And((P=0)Or(P2<P)) Then P:=P2;
 If P>0 Then Begin
  Nm:=Copy(Arg,1,P-1); Vl:=TrimStr(Copy(Arg,P+1,255));
 End
  Else
 Begin
  Nm:=Arg; Vl:='';
 End;
 Nm:=UpStr(Nm); U:=UpStr(Vl);
 If (Nm='?')Or(Nm='HELP')Or(Nm='H') Then ShowHelp Else
 If Nm='VERSION' Then Begin
  WriteLn('CS3DA ',AppVersion);
  Halt(0);
 End
  Else
 If Nm='CONFIG' Then Begin
  If Not InCfg Then Begin
   InCfg:=True;
   ReadConfigFile(Vl);
   InCfg:=False;
  End;
 End
  Else
 If Nm='PROFILE' Then ProfName:=Vl Else
 If Nm='LOG' Then Begin
  If Not LogOn Then Begin
   Assign(LogF,Vl);
   {$I-}Rewrite(LogF);{$I+}
   LogOn:=IOResult=0;
   If LogOn Then LogMsg('CS3DA '+AppVersion+' - journal de diagnostique');
  End;
 End
  Else
 If Nm='QUIET' Then OptQuiet:=True Else
 If Nm='VIEW' Then ViewName:=U Else
 If Nm='MODEL' Then ModelFile:=Vl Else
 If Nm='SHOW' Then ShowHideList(Vl,True) Else
 If Nm='HIDE' Then ShowHideList(Vl,False) Else
 If Nm='CAMERA' Then CamName:=U Else
 If Nm='ZOOM' Then Begin
  OptZoom:=StrReal(Vl,1.0);
  If OptZoom<0.2 Then OptZoom:=0.2;
  If OptZoom>20 Then OptZoom:=20;
  ZoomGiven:=True;
 End
  Else
 If Nm='BACKGROUND' Then Begin
  GridOn:=False;
  If U='GRID' Then Begin GridOn:=True; BgCol:=Black; End Else
  If U='DARK' Then BgCol:=DarkGray Else
  If ColorByName(U)>=0 Then BgCol:=ColorByName(U)
   Else Warn('Arriere-plan inconnu : '+Vl);
 End
  Else
 If Nm='HEART' Then Begin
  OptHR:=Round(StrReal(Vl,72)); HRGiven:=True;
  If (OptHR<30)Or(OptHR>220) Then Begin
   Warn('Frequence cardiaque hors limites (30-220)');
   If OptHR<30 Then OptHR:=30 Else OptHR:=220;
  End;
 End
  Else
 If Nm='FLOW' Then Begin
  If (U='OFF')Or(U='NONE') Then FlowMode:=0 Else
  If (U='ANIMATED')Or(U='ON')Or(U='') Then FlowMode:=1 Else
  If U='PULSATILE' Then FlowMode:=2 Else
  If (U='ARROWS')Or(U='STATIC') Then FlowMode:=3
   Else Warn('Mode de flux inconnu : '+Vl);
 End
  Else
 If Nm='OXYGEN' Then Begin
  If (U='OFF')Or(U='NONE') Then OxyMode:=0 Else
  If (U='COLOR')Or(U='ON')Or(U='') Then OxyMode:=1 Else
  If (U='GRADIENT')Or(U='SATURATION') Then OxyMode:=2
   Else Warn('Mode d''oxygenation inconnu : '+Vl);
 End
  Else
 If Nm='VESSELS' Then SetVessels(Vl) Else
 If Nm='PRESSURE' Then Begin
  OptPr:=Round(StrReal(Vl,120)); PrGiven:=True;
  If OptPr<70 Then OptPr:=70;
  If OptPr>240 Then OptPr:=240;
 End
  Else
 If Nm='SPEED' Then Begin
  OptSpd:=StrReal(Vl,1.0); SpdGiven:=True;
  If OptSpd<0.1 Then OptSpd:=0.1;
  If OptSpd>10 Then OptSpd:=10;
 End
  Else
 If Nm='PLAY' Then Playing:=True Else
 If Nm='PAUSE' Then Playing:=False Else
 If Nm='STOP' Then Begin Playing:=False; SimT:=0; CycleAcc:=0; End Else
 If Nm='LOOP' Then Looping:=True Else
 If Nm='DURATION' Then Begin
  Val(Vl,R,C);
  If (C=0)And(R>=0) Then Duration:=R Else Warn('Duree invalide : '+Vl);
 End
  Else
 If Nm='FPS' Then Begin
  FPS:=Round(StrReal(Vl,25));
  If FPS<1 Then FPS:=1;
  If FPS>60 Then FPS:=60;
 End
  Else
 If Nm='IMPORT' Then Begin
  If NImp<4 Then Begin Inc(NImp); ImpFiles[NImp]:=Vl; End;
 End
  Else
 If Nm='EXPORT' Then ExpFile:=Vl Else
 If Nm='FORMAT' Then FmtName:=U Else
 Warn('Option inconnue : '+Arg);
End;

{ ====================================================================
  Initialisation
  ==================================================================== }

Procedure InitDefaults;
Var
 D:DirStr; N:NameStr; E:ExtStr;
Begin
 FSplit(ParamStr(0),D,N,E);
 ExeDir:=D;
 OptQuiet:=False; ModelFile:=''; ProfName:='REST';
 ExpFile:=''; FmtName:=''; ViewName:='FULLBODY'; CamName:='FRONT'; NImp:=0;
 HRGiven:=False; PrGiven:=False; SpdGiven:=False; ZoomGiven:=False;
 ShowListed:=False; InCfg:=False; LogOn:=False; GfxOn:=False;
 ShowArt:=True; ShowVein:=True; ShowCap:=True; ShowHeart:=True; ShowLung:=True;
 ShowBody:=True; ShowBlood:=True; ShowLabels:=False; ShowInfo:=True;
 ShowTrace:=True; ShowSys:=True; ShowPul:=True; GridOn:=False;
 FlowMode:=1; OxyMode:=1; BgCol:=Black; Sel:=0;
 Yaw:=0; Pitch:=0; Zoom:=1.0; TgX:=0; TgY:=90; TgZ:=0; OffX:=0; OffY:=0;
 Orbit:=False; CamIdx:=0; CurView:='FULLBODY';
 Playing:=True; Looping:=False; Duration:=0; SimT:=0; CycleAcc:=0; FPS:=20;
 HeartKey:=0; LastHeartKey:=-1;
 HX1:=0; HY1:=0; HX2:=-1; HY2:=-1; PHX1:=0; PHY1:=0; PHX2:=-1; PHY2:=-1;
 NeedAll:=True; NeedFull:=True; NeedInfo:=True; Quit:=False; LastInfo:=0;
 StatusMsg:='Pret. F10 = menus, F1 = aide';
 NOld:=0; TrHead:=0; NPart:=0;
 ClearModel;
 DefaultPhysio;
End;

Procedure AllocModel;
Begin
 New(Vtx); New(VCam); New(Vsc); New(Faces); New(Pts); New(PCam); New(Psc);
End;

Var
 I:Integer;
 Mp:String;
 Ok:Boolean;

BEGIN
 Randomize;
 InitDefaults;
 AllocModel;
 { ---- options ---- }
 For I:=1 To ParamCount Do ParseOption(ParamStr(I));
 { ---- physiologie ---- }
 LoadPhysio('PHYSIO.CFG');
 If Not ApplyProfile(ProfName) Then Begin
  Warn('Profil inconnu : '+ProfName);
  ApplyProfile('REST');
 End;
 If HRGiven Then HR:=OptHR;
 If PrGiven Then Begin
  PDia:=Round(PDia*OptPr/PSys); PSys:=OptPr;
 End;
 If SpdGiven Then SpeedF:=OptSpd;
 BuildTables;
 { ---- modele ---- }
 If ModelFile='' Then Mp:='HUMAN.C3D' Else Mp:=ModelFile;
 Ok:=LoadModel(Mp,False);
 If Not Ok Then Begin
  WriteLn('Erreur : impossible de charger le modele anatomique ',Mp);
  WriteLn('Le fichier doit se trouver dans SAMPLES',DirSep,'CS3DA');
  If LogOn Then Close(LogF);
  Halt(1);
 End;
 For I:=1 To NImp Do If Not LoadModel(ImpFiles[I],True) Then
  Warn('Importation impossible : '+ImpFiles[I]);
 { ---- exportation sans interface graphique ---- }
 If ExpFile<>'' Then Begin
  ExportSim(ExpFile,FormatOf(ExpFile));
  If LogOn Then Close(LogF);
  Halt(0);
 End;
 ApplyView(ViewName);
 If ZoomGiven Then Zoom:=OptZoom;
 SetCamera(CamName);
 BuildMenus;
 If Not MouseDriverFound Then Warn('Pilote de souris absent : clavier uniquement');
 { ---- graphique ---- }
 InitializeGraphics;
 GfxOn:=True;
 {$IFDEF FPC}
  CurSize:=ImageSize(0,0,11,15);
  GetMem(CurBuf,CurSize);
  CurOn:=False;
 {$ENDIF}
 ShowMouse;
 MainLoop;
 HideMouse;
 CloseGraph;
 If LogOn Then Begin
  LogMsg('Fin normale du programme');
  Close(LogF);
 End;
END.
