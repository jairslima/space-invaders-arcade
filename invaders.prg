/*
 * Space Invaders Arcade by Jair Lima
 *
 * Space Invaders em modo texto (Harbour 3.0 + GTWIN) no estilo fliperama:
 * formacao de 55 invasores que acelera conforme morrem, bunkers que se
 * desgastam, disco voador misterioso, bombas inimigas, vidas, ondas,
 * recordes com iniciais e efeitos sonoros sintetizados com prioridade
 * (um canal de som so, o efeito mais importante vence).
 *
 * Teclado: usa o estado real das teclas (GetAsyncKeyState, via funcao C
 * embutida) para andar e atirar ao mesmo tempo. Se a deteccao falhar no
 * terminal, cai sozinho para os eventos de teclado (Inkey).
 *
 * Fonte em ASCII puro: blocos/molduras via Chr() (codepage OEM).
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "hbgtinfo.ch"

#define FL          2            // coluna inicial do campo
#define FWID       76            // largura do campo (colunas)
#define ROW_UFO     3            // faixa do disco voador
#define ROW_SHIP   22            // linha da nave
#define ROW_FLOOR  23            // linha do chao
#define BUN_TOP    18            // primeira linha dos bunkers
#define NROWS       5            // fileiras de invasores
#define NCOLS      11            // colunas de invasores
#define TICK_MS    30            // duracao de um tick
#define SND_FLAGS  131075        // SND_ASYNC + SND_FILENAME + SND_NODEFAULT
#define HI_FILE    "invaders.sco"

#define VK_SPACE   32
#define VK_LEFT    37
#define VK_RIGHT   39

#define BLK        Chr( 219 )
#define SHD        Chr( 178 )
#define MSH        Chr( 177 )
#define LSH        Chr( 176 )

// ---- estado de modulo ----
STATIC s_aHi
STATIC s_cTmp
STATIC s_lSnd := .T.
STATIC s_hDur := { => }
STATIC s_nBusyUntil := 0
STATIC s_nBusyPrio := 0
STATIC s_nAsync := 0             // 0 desconhecido, 1 teclado direto OK, -1 usar Inkey
STATIC s_nMiss := 0

STATIC s_aAl                     // invasores vivos [fileira][coluna]
STATIC s_nOx, s_nOy, s_nDir, s_nFrame, s_nStepCnt, s_nMarch
STATIC s_nShipX
STATIC s_lPb, s_nPbx, s_nPby     // tiro do jogador
STATIC s_aBombs                  // bombas { x, y }
STATIC s_aBun                    // bunkers [4][3][7] com resistencia
STATIC s_lUfo, s_nUx, s_nUdir, s_nUpts, s_nUfoWait
STATIC s_aFx                     // efeitos { x, y, txt, cor, ticks }
STATIC s_nScore, s_nLives, s_nLevel, s_nExtra
STATIC s_lHit, s_lHud

PROCEDURE Main( cArg )

   hb_gtInfo( HB_GTI_WINTITLE, "Space Invaders Arcade by Jair Lima" )

   TimerRes( 1 )
   LoadHi()

   IF cArg != NIL .AND. Lower( cArg ) == "--selftest"
      SelfTest()
      RETURN
   ENDIF

   IF MaxRow() < 24 .OR. MaxCol() < 79
      ? "Space Invaders Arcade by Jair Lima precisa de um terminal de pelo menos 80x25."
      RETURN
   ENDIF

   InitSound()
   SetCursor( SC_NONE )
   SetColor( "W/N" )

   DO WHILE TitleScreen()
      PlayGame()
   ENDDO

   SetColor( "W/N" )
   CLS
   SetCursor( SC_NORMAL )
   ? "Obrigado por jogar Space Invaders Arcade by Jair Lima!"
   ?

RETURN

// ---------------------------------------------------------------------
// Tela de abertura
// ---------------------------------------------------------------------

STATIC FUNCTION TitleScreen()

   LOCAL aLet := { ;
      { "#####", "  #  ", "  #  ", "  #  ", "#####" }, ;
      { "#   #", "##  #", "# # #", "#  ##", "#   #" }, ;
      { "#   #", "#   #", "#   #", " # # ", "  #  " }, ;
      { " ### ", "#   #", "#####", "#   #", "#   #" }, ;
      { "#### ", "#   #", "#   #", "#   #", "#### " }, ;
      { "#####", "#    ", "#### ", "#    ", "#####" }, ;
      { "#### ", "#   #", "#### ", "#  # ", "#   #" }, ;
      { " ####", "#    ", " ### ", "    #", "#### " } }
   LOCAL aClr := { "R+/N", "Y+/N", "G+/N", "C+/N", "M+/N", "W+/N" }
   LOCAL nTick := 0, nPos := 0, nDir := 1, nFr, k, i, r, cRow, cAt

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S P A C E   I N V A D E R S   A R C A D E   by Jair Lima", 80 ), "N/W" )
   hb_DispOutAt( 2, 0, PadC( "S  P  A  C  E", 80 ), "C+/N" )

   hb_DispOutAt( 11, 14, "* SCORE ADVANCE TABLE *", "W/N" )
   hb_DispOutAt( 13, 14, "<oOo>  = ? MYSTERY", "R+/N" )
   hb_DispOutAt( 14, 14, "/M\    = 30 PTS", "M+/N" )
   hb_DispOutAt( 15, 14, "{O}    = 20 PTS", "C+/N" )
   hb_DispOutAt( 16, 14, "<W>    = 10 PTS", "G+/N" )

   hb_DispOutAt( 11, 48, "HIGH SCORES", "Y+/N" )
   FOR i := 1 TO Len( s_aHi )
      hb_DispOutAt( 12 + i, 48, Str( i, 1 ) + "  " + s_aHi[ i ][ 1 ] + "  " + StrZero( s_aHi[ i ][ 2 ], 6 ), ;
         IIF( i == 1, "G+/N", "W/N" ) )
   NEXT

   hb_DispOutAt( 22, 0, PadC( "SETAS/AD mover   ESPACO atirar   P pausa   M som   ESC sair", 80 ), "W/N" )
   hb_DispOutAt( 24, 0, PadC( "(c) Jair Lima - Harbour + GTWIN", 79 ), "N+/N" )

   DO WHILE .T.

      FOR i := 1 TO 8
         FOR r := 1 TO 5
            cRow := StrTran( aLet[ i ][ r ], "#", BLK )
            hb_DispOutAt( 4 + r, 13 + ( i - 1 ) * 7, cRow, aClr[ ( Int( nTick / 3 ) + i ) % 6 + 1 ] )
         NEXT
      NEXT

      IF nTick % 10 < 6
         hb_DispOutAt( 18, 0, PadC( "*** INSERT COIN - PRESS ENTER ***", 80 ), "R+/N" )
      ELSE
         hb_DispOutAt( 18, 0, Space( 80 ), "W/N" )
      ENDIF

      // invasores desfilando
      nFr := Int( nTick / 4 ) % 2
      hb_DispOutAt( 20, 0, Space( 80 ), "W/N" )
      cAt := 10 + nPos
      FOR i := 0 TO 7
         hb_DispOutAt( 20, cAt + i * 5, Sprite( 1 + ( i % 3 ) * 2, nFr ), ;
            { "M+/N", "C+/N", "G+/N" }[ i % 3 + 1 ] )
      NEXT
      IF nTick % 6 == 0
         nPos += nDir
         IF nPos > 24 .OR. nPos < 0
            nDir := -nDir
            nPos += nDir
         ENDIF
      ENDIF

      hb_DispOutAt( 23, 0, PadC( IIF( s_lSnd, "SOM: LIGADO", "SOM: DESLIGADO" ), 80 ), "N+/N" )

      k := Inkey( 0.07 )
      nTick++

      DO CASE
      CASE k == K_ENTER .OR. k == 32
         PlaySfx( "coin", 5 )
         Inkey( 0.5 )
         RETURN .T.
      CASE k == K_ESC
         RETURN .F.
      CASE k == Asc( "m" ) .OR. k == Asc( "M" )
         s_lSnd := ! s_lSnd
      ENDCASE

   ENDDO

RETURN .T.

// ---------------------------------------------------------------------
// Jogo
// ---------------------------------------------------------------------

STATIC PROCEDURE PlayGame()

   LOCAL k, nNext, nTick, lQuit := .F., lNewWave := .T., lLanded := .F.
   LOCAL nDx, nEv, lFire, lJust, lL, lR, nOldOy, nAlive, nBombEvery

   s_nScore := 0
   s_nLives := 3
   s_nLevel := 1
   s_nExtra := 2000
   s_nShipX := FL + Int( FWID / 2 ) - 1
   s_lHit := .F.
   s_lHud := .T.

   DrawFrame()

   DO WHILE s_nLives > 0 .AND. ! lQuit .AND. ! lLanded

      IF lNewWave
         NewWave()
         lNewWave := .F.
         RenderAll()
         HudAll()
         Banner( "WAVE " + hb_ntos( s_nLevel ), "G+/N" )
         PlaySfx( "start", 5 )
         Inkey( 1.4 )
      ENDIF
      RenderAll()
      hb_keyClear()

      nTick := 0
      nNext := hb_MilliSeconds() + TICK_MS

      DO WHILE AliveCount() > 0 .AND. ! lLanded .AND. ! s_lHit .AND. ! lQuit

         // ---------- entrada ----------
         nDx := 0
         nEv := 0
         lFire := .F.
         DO WHILE ( k := Inkey() ) != 0
            DO CASE
            CASE k == K_LEFT .OR. k == Asc( "a" ) .OR. k == Asc( "A" )
               nEv--
               ProbeAsync( IIF( k == K_LEFT, VK_LEFT, 65 ) )
            CASE k == K_RIGHT .OR. k == Asc( "d" ) .OR. k == Asc( "D" )
               nEv++
               ProbeAsync( IIF( k == K_RIGHT, VK_RIGHT, 68 ) )
            CASE k == 32
               lFire := .T.
            CASE k == Asc( "m" ) .OR. k == Asc( "M" )
               s_lSnd := ! s_lSnd
            CASE k == Asc( "p" ) .OR. k == Asc( "P" )
               PlaySfx( "pause", 5 )
               Banner( "PAUSED - press any key", "Y+/N" )
               Inkey( 0 )
               RenderAll()
               nNext := hb_MilliSeconds() + TICK_MS
            CASE k == K_ESC
               Banner( "QUIT GAME? (S/N)", "R+/N" )
               DO WHILE .T.
                  k := Inkey( 0 )
                  IF k == Asc( "s" ) .OR. k == Asc( "S" ) .OR. k == Asc( "y" ) .OR. k == Asc( "Y" )
                     lQuit := .T.
                     EXIT
                  ELSEIF k == Asc( "n" ) .OR. k == Asc( "N" ) .OR. k == K_ESC
                     EXIT
                  ENDIF
               ENDDO
               IF ! lQuit
                  RenderAll()
                  nNext := hb_MilliSeconds() + TICK_MS
               ENDIF
            ENDCASE
            IF lQuit
               EXIT
            ENDIF
         ENDDO
         IF lQuit
            EXIT
         ENDIF

         IF s_nAsync == 1
            lL := KeyDown( VK_LEFT ) .OR. KeyDown( 65 )
            lR := KeyDown( VK_RIGHT ) .OR. KeyDown( 68 )
            nDx := IIF( lR, 1, 0 ) - IIF( lL, 1, 0 )
            IF nDx == 0 .AND. nEv != 0          // toque rapido ja solto: ainda anda 1
               nDx := IIF( nEv > 0, 1, -1 )
            ENDIF
            IF KeyDown( VK_SPACE )
               lFire := .T.
            ENDIF
         ELSE
            nDx := Max( -2, Min( 2, nEv ) )
         ENDIF

         nTick++

         // ---------- nave ----------
         IF nDx != 0
            hb_DispOutAt( ROW_SHIP, s_nShipX, "   ", "W/N" )
            s_nShipX := Max( FL, Min( FL + FWID - 3, s_nShipX + nDx ) )
         ENDIF
         DrawShip()

         lJust := .F.
         IF lFire .AND. ! s_lPb
            s_lPb := .T.
            s_nPbx := s_nShipX + 1
            s_nPby := ROW_SHIP - 1
            lJust := .T.
            PlaySfx( "shoot", 2 )
            IF CheckBulletHit()              // tiro que nasce dentro de um invasor ja acerta
               s_lPb := .F.
            ELSE
               hb_DispOutAt( s_nPby, s_nPbx, "|", "Y+/N" )
            ENDIF
         ENDIF

         // ---------- tiro do jogador (nao anda no tick em que nasceu) ----------
         IF s_lPb .AND. ! lJust
            MovePlayerBullet()
         ENDIF

         // ---------- formacao ----------
         s_nStepCnt++
         nAlive := AliveCount()
         IF nAlive > 0 .AND. s_nStepCnt >= StepTicks( nAlive, s_nLevel )
            s_nStepCnt := 0
            nOldOy := s_nOy
            StepFormation()
            ClearBunkersUnderAliens()
            DrawAliens( nOldOy )
            DrawBunkers()
            s_nMarch := s_nMarch % 4 + 1
            PlaySfx( "march" + hb_ntos( s_nMarch ), 1 )
            IF s_lPb .AND. CheckBulletHit()
               s_lPb := .F.                  // sem apagar: o acerto ja redesenhou a celula
            ENDIF
            DrawShots()
            IF Landed()
               lLanded := .T.
            ENDIF
         ENDIF

         // ---------- bombas ----------
         nBombEvery := Max( 2, 3 - Int( s_nLevel / 3 ) )
         IF nTick % nBombEvery == 0
            MoveBombs()
         ENDIF
         EnemyFire()

         // ---------- disco voador e efeitos ----------
         UpdateUfo( nTick )
         UpdateFx()

         IF s_lHud
            HudAll()
         ENDIF

         // ---------- ritmo ----------
         DO WHILE hb_MilliSeconds() < nNext
            SleepMs( 1 )
         ENDDO
         nNext += TICK_MS
         IF hb_MilliSeconds() > nNext + 3 * TICK_MS
            nNext := hb_MilliSeconds() + TICK_MS
         ENDIF

      ENDDO

      IF lQuit
         EXIT
      ENDIF

      IF lLanded
         Banner( "THE INVADERS HAVE LANDED!", "R+/N" )
         PlaySfx( "playerdie", 5 )
         Inkey( 2.5 )
         EXIT
      ENDIF

      IF s_lHit
         PlayerDeath()
         s_lHit := .F.
         IF s_nLives > 0
            lNewWave := .F.
         ENDIF
         LOOP
      ENDIF

      // onda limpa
      s_nScore += 100 * s_nLevel
      CheckExtra()
      HudAll()
      Banner( "WAVE CLEARED!", "Y+/N" )
      PlaySfx( "wave", 5 )
      Inkey( 1.8 )
      s_nLevel++
      lNewWave := .T.

   ENDDO

   IF ! lQuit
      Banner( "G A M E   O V E R", "R+/N" )
      PlaySfx( "gameover", 5 )
      Inkey( 3 )
      hb_keyClear()
   ENDIF

   CheckHi( s_nScore )

RETURN

STATIC PROCEDURE ProbeAsync( nVk )

   // compara cada evento de seta com o estado real da tecla: se a tecla aparece
   // pressionada, o teclado direto funciona (liga ou religa); so cai para o
   // fallback depois de 8 eventos seguidos sem nenhuma tecla vista como pressionada
   // (toques muito rapidos nao desligam o modo direto)
   IF KeyDown( nVk )
      s_nMiss := 0
      s_nAsync := 1
   ELSE
      s_nMiss++
      IF s_nMiss >= 8
         s_nAsync := -1
      ENDIF
   ENDIF

RETURN

// ---------------------------------------------------------------------
// Regras
// ---------------------------------------------------------------------

STATIC PROCEDURE NewWave()

   LOCAL r

   s_aAl := {}
   FOR r := 1 TO NROWS
      AAdd( s_aAl, AFill( Array( NCOLS ), .T. ) )
   NEXT
   s_nOx := FL + 4
   s_nOy := Min( 5 + ( s_nLevel - 1 ), 9 )
   s_nDir := 1
   s_nFrame := 0
   s_nStepCnt := 0
   s_nMarch := 0
   s_lPb := .F.
   s_aBombs := {}
   s_aFx := {}
   s_lUfo := .F.
   s_nUfoWait := hb_RandomInt( 600, 900 )
   s_lHit := .F.
   MakeBunkers()

RETURN

STATIC FUNCTION AliveCount()

   LOCAL r, c, n := 0

   IF s_aAl == NIL
      RETURN 0
   ENDIF
   FOR r := 1 TO NROWS
      FOR c := 1 TO NCOLS
         IF s_aAl[ r ][ c ]
            n++
         ENDIF
      NEXT
   NEXT

RETURN n

// ticks entre passos da formacao: menos invasores = mais rapido
STATIC FUNCTION StepTicks( nAlive, nLevel )
RETURN Max( 2, Int( nAlive * Max( 8, 22 - 2 * ( nLevel - 1 ) ) / ( NROWS * NCOLS ) ) )   // piso: o ultimo invasor continua acertavel

STATIC FUNCTION AlienPoints( r )

   DO CASE
   CASE r == 1
      RETURN 30
   CASE r <= 3
      RETURN 20
   ENDCASE

RETURN 10

STATIC PROCEDURE BoundsCols( /*@*/ nMin, /*@*/ nMax )

   LOCAL r, c

   nMin := NCOLS + 1
   nMax := 0
   FOR r := 1 TO NROWS
      FOR c := 1 TO NCOLS
         IF s_aAl[ r ][ c ]
            nMin := Min( nMin, c )
            nMax := Max( nMax, c )
         ENDIF
      NEXT
   NEXT

RETURN

// avanca a formacao um passo; retorna .T. se desceu uma linha
STATIC FUNCTION StepFormation()

   LOCAL cMin, cMax, lDrop := .F., nNext

   BoundsCols( @cMin, @cMax )
   nNext := s_nOx + s_nDir

   IF ( s_nDir > 0 .AND. nNext + ( cMax - 1 ) * 4 + 2 > FL + FWID - 1 ) .OR. ;
      ( s_nDir < 0 .AND. nNext + ( cMin - 1 ) * 4 < FL )
      s_nOy++
      s_nDir := -s_nDir
      lDrop := .T.
   ELSE
      s_nOx := nNext
   ENDIF
   s_nFrame := 1 - s_nFrame

RETURN lDrop

STATIC FUNCTION Landed()

   LOCAL r, c

   FOR r := NROWS TO 1 STEP -1
      FOR c := 1 TO NCOLS
         IF s_aAl[ r ][ c ]
            RETURN ( s_nOy + 2 * ( r - 1 ) ) >= ROW_SHIP
         ENDIF
      NEXT
   NEXT

RETURN .F.

// invasor na posicao (x,y)? retorna { fileira, coluna } ou NIL
STATIC FUNCTION FindAlien( x, y )

   LOCAL dy := y - s_nOy, dx := x - s_nOx, r, c

   IF dy < 0 .OR. dy % 2 != 0 .OR. dx < 0 .OR. dx % 4 > 2
      RETURN NIL
   ENDIF
   r := Int( dy / 2 ) + 1
   c := Int( dx / 4 ) + 1
   IF r > NROWS .OR. c > NCOLS
      RETURN NIL
   ENDIF
   IF ! s_aAl[ r ][ c ]
      RETURN NIL
   ENDIF

RETURN { r, c }

STATIC FUNCTION ShipHit( x, y )
RETURN y == ROW_SHIP .AND. x >= s_nShipX .AND. x <= s_nShipX + 2

STATIC PROCEDURE CheckExtra()

   DO WHILE s_nScore >= s_nExtra
      s_nExtra += 2000
      IF s_nLives < 5
         s_nLives++
         PlaySfx( "wave", 5 )
      ENDIF
   ENDDO
   s_lHud := .T.

RETURN

// ---------- bunkers ----------

STATIC FUNCTION BunX( k )
RETURN FL + 10 + ( k - 1 ) * 18

STATIC PROCEDURE MakeBunkers()

   LOCAL k, r, c, aShape := { ;
      { 0, 3, 3, 3, 3, 3, 0 }, ;
      { 3, 3, 3, 3, 3, 3, 3 }, ;
      { 3, 3, 3, 0, 3, 3, 3 } }

   s_aBun := {}
   FOR k := 1 TO 4
      AAdd( s_aBun, {} )
      FOR r := 1 TO 3
         AAdd( s_aBun[ k ], AClone( aShape[ r ] ) )
      NEXT
   NEXT

RETURN

STATIC FUNCTION BunGlyph( nHp )

   DO CASE
   CASE nHp >= 3
      RETURN BLK
   CASE nHp == 2
      RETURN SHD
   CASE nHp == 1
      RETURN MSH
   ENDCASE

RETURN " "

STATIC PROCEDURE DrawBunkers()

   LOCAL k, r, c

   FOR k := 1 TO 4
      FOR r := 1 TO 3
         FOR c := 1 TO 7
            IF s_aBun[ k ][ r ][ c ] > 0
               hb_DispOutAt( BUN_TOP + r - 1, BunX( k ) + c - 1, BunGlyph( s_aBun[ k ][ r ][ c ] ), "G/N" )
            ENDIF
         NEXT
      NEXT
   NEXT

RETURN

// dano num bunker em (x,y): retorna .T. se havia bloco
STATIC FUNCTION BunkerHit( x, y, nDmg )

   LOCAL k, r, c, bx

   IF y < BUN_TOP .OR. y > BUN_TOP + 2
      RETURN .F.
   ENDIF
   FOR k := 1 TO 4
      bx := BunX( k )
      IF x >= bx .AND. x <= bx + 6
         r := y - BUN_TOP + 1
         c := x - bx + 1
         IF s_aBun[ k ][ r ][ c ] > 0
            s_aBun[ k ][ r ][ c ] := Max( 0, s_aBun[ k ][ r ][ c ] - nDmg )
            hb_DispOutAt( y, x, BunGlyph( s_aBun[ k ][ r ][ c ] ), "G/N" )
            RETURN .T.
         ENDIF
      ENDIF
   NEXT

RETURN .F.

STATIC PROCEDURE ClearBunkersUnderAliens()

   LOCAL r, c, y, i

   FOR r := 1 TO NROWS
      y := s_nOy + 2 * ( r - 1 )
      IF y >= BUN_TOP .AND. y <= BUN_TOP + 2
         FOR c := 1 TO NCOLS
            IF s_aAl[ r ][ c ]
               FOR i := 0 TO 2
                  BunkerHit( s_nOx + ( c - 1 ) * 4 + i, y, 9 )
               NEXT
            ENDIF
         NEXT
      ENDIF
   NEXT

RETURN

// ---------- tiros ----------

STATIC FUNCTION CheckBulletHit()

   LOCAL a

   // disco voador
   IF s_lUfo .AND. s_nPby == ROW_UFO .AND. s_nPbx >= s_nUx .AND. s_nPbx <= s_nUx + 4
      KillUfo()
      RETURN .T.
   ENDIF

   a := FindAlien( s_nPbx, s_nPby )
   IF a != NIL
      KillAlien( a[ 1 ], a[ 2 ] )
      RETURN .T.
   ENDIF

   IF BunkerHit( s_nPbx, s_nPby, 1 )
      PlaySfx( "bunker", 2 )
      RETURN .T.
   ENDIF

RETURN .F.

STATIC PROCEDURE KillPlayerBullet()

   hb_DispOutAt( s_nPby, s_nPbx, " ", "W/N" )
   s_lPb := .F.

RETURN

STATIC PROCEDURE MovePlayerBullet()

   hb_DispOutAt( s_nPby, s_nPbx, " ", "W/N" )
   s_nPby--
   IF s_nPby < ROW_UFO
      s_lPb := .F.
      RETURN
   ENDIF
   IF CheckBulletHit() .OR. BulletBombHit()
      s_lPb := .F.
      RETURN
   ENDIF
   hb_DispOutAt( s_nPby, s_nPbx, "|", "Y+/N" )

RETURN

// tiro x bomba checado TODO tick (a bomba anda a cada 2-3 ticks e o tiro 1 por tick:
// checar so quando a bomba anda deixava o tiro atravessar a bomba)
STATIC FUNCTION BulletBombHit()

   LOCAL i, b

   IF ! s_lPb
      RETURN .F.
   ENDIF
   FOR i := Len( s_aBombs ) TO 1 STEP -1
      b := s_aBombs[ i ]
      IF s_nPbx == b[ 1 ] .AND. Abs( s_nPby - b[ 2 ] ) <= 1
         hb_DispOutAt( b[ 2 ], b[ 1 ], " ", "W/N" )
         hb_ADel( s_aBombs, i, .T. )
         AddFx( b[ 1 ], b[ 2 ], "*", "Y+/N", 3 )
         PlaySfx( "bunker", 2 )
         RETURN .T.
      ENDIF
   NEXT

RETURN .F.

STATIC PROCEDURE KillAlien( r, c )

   LOCAL x := s_nOx + ( c - 1 ) * 4, y := s_nOy + 2 * ( r - 1 )

   s_aAl[ r ][ c ] := .F.
   s_nScore += AlienPoints( r )
   PlaySfx( "alienhit", 3 )
   hb_DispOutAt( y, x, "   ", "W/N" )
   AddFx( x, y, "\|/", "Y+/N", 4 )
   CheckExtra()

RETURN

STATIC PROCEDURE DrawShots()

   LOCAL b

   IF s_lPb
      hb_DispOutAt( s_nPby, s_nPbx, "|", "Y+/N" )
   ENDIF
   FOR EACH b IN s_aBombs
      hb_DispOutAt( b[ 2 ], b[ 1 ], IIF( b[ 2 ] % 2 == 0, "!", "i" ), "R+/N" )
   NEXT

RETURN

STATIC PROCEDURE MoveBombs()

   LOCAL i, b, lGone

   FOR i := Len( s_aBombs ) TO 1 STEP -1
      b := s_aBombs[ i ]
      hb_DispOutAt( b[ 2 ], b[ 1 ], " ", "W/N" )
      b[ 2 ]++
      lGone := .F.

      IF s_lPb .AND. s_nPbx == b[ 1 ] .AND. Abs( s_nPby - b[ 2 ] ) <= 1
         KillPlayerBullet()
         AddFx( b[ 1 ], b[ 2 ], "*", "Y+/N", 3 )
         PlaySfx( "bunker", 2 )
         lGone := .T.
      ELSEIF ShipHit( b[ 1 ], b[ 2 ] )
         s_lHit := .T.
         lGone := .T.
      ELSEIF b[ 2 ] >= ROW_FLOOR
         lGone := .T.
      ELSEIF BunkerHit( b[ 1 ], b[ 2 ], 2 )
         PlaySfx( "bunker", 2 )
         lGone := .T.
      ENDIF

      IF lGone
         hb_ADel( s_aBombs, i, .T. )
      ELSE
         hb_DispOutAt( b[ 2 ], b[ 1 ], IIF( b[ 2 ] % 2 == 0, "!", "i" ), "R+/N" )
      ENDIF
   NEXT

RETURN

STATIC PROCEDURE EnemyFire()

   LOCAL aCols := {}, c, r, nMax := 3 + Min( s_nLevel, 3 ), nChance := Min( 8, 3 + s_nLevel )

   IF Len( s_aBombs ) >= nMax .OR. hb_RandomInt( 1, 100 ) > nChance
      RETURN
   ENDIF

   FOR c := 1 TO NCOLS
      FOR r := 1 TO NROWS
         IF s_aAl[ r ][ c ]
            AAdd( aCols, c )
            EXIT
         ENDIF
      NEXT
   NEXT
   IF Empty( aCols )
      RETURN
   ENDIF

   c := aCols[ hb_RandomInt( 1, Len( aCols ) ) ]
   FOR r := NROWS TO 1 STEP -1
      IF s_aAl[ r ][ c ]
         AAdd( s_aBombs, { s_nOx + ( c - 1 ) * 4 + 1, s_nOy + 2 * ( r - 1 ) + 1 } )
         hb_DispOutAt( ATail( s_aBombs )[ 2 ], ATail( s_aBombs )[ 1 ], ;
            IIF( ATail( s_aBombs )[ 2 ] % 2 == 0, "!", "i" ), "R+/N" )
         EXIT
      ENDIF
   NEXT

RETURN

// ---------- disco voador ----------

STATIC PROCEDURE UpdateUfo( nTick )

   IF ! s_lUfo
      s_nUfoWait--
      IF s_nUfoWait <= 0 .AND. AliveCount() >= 8
         s_lUfo := .T.
         s_nUdir := IIF( hb_RandomInt( 0, 1 ) == 0, 1, -1 )
         s_nUx := IIF( s_nUdir > 0, FL, FL + FWID - 5 )
         s_nUpts := { 50, 50, 100, 100, 100, 150, 150, 300 }[ hb_RandomInt( 1, 8 ) ]   // 300 e raro
         PlaySfx( "ufo", 2 )
      ENDIF
      RETURN
   ENDIF

   IF nTick % 2 == 0
      hb_DispOutAt( ROW_UFO, s_nUx, "     ", "W/N" )
      s_nUx += s_nUdir
      IF s_nUx < FL .OR. s_nUx > FL + FWID - 5
         s_lUfo := .F.
         s_nUfoWait := hb_RandomInt( 600, 900 )
         RETURN
      ENDIF
   ENDIF
   hb_DispOutAt( ROW_UFO, s_nUx, "<oOo>", "R+/N" )
   IF nTick % 5 == 0                         // o warble dura 140 ms: repete sem silencio
      PlaySfx( "ufo", 2 )
   ENDIF

RETURN

STATIC PROCEDURE KillUfo()

   hb_DispOutAt( ROW_UFO, s_nUx, "     ", "W/N" )
   s_nScore += s_nUpts
   AddFx( s_nUx, ROW_UFO, "+" + hb_ntos( s_nUpts ), "Y+/N", 25 )
   PlaySfx( "ufohit", 4 )
   s_lUfo := .F.
   s_nUfoWait := hb_RandomInt( 600, 900 )
   CheckExtra()

RETURN

// ---------- efeitos visuais ----------

STATIC PROCEDURE AddFx( x, y, cTxt, cClr, nTicks )

   AAdd( s_aFx, { x, y, cTxt, cClr, nTicks } )
   hb_DispOutAt( y, x, cTxt, cClr )

RETURN

STATIC PROCEDURE UpdateFx()

   LOCAL i, f

   FOR i := Len( s_aFx ) TO 1 STEP -1
      f := s_aFx[ i ]
      f[ 5 ]--
      IF f[ 5 ] <= 0
         hb_DispOutAt( f[ 2 ], f[ 1 ], Space( Len( f[ 3 ] ) ), "W/N" )
         hb_ADel( s_aFx, i, .T. )
      ENDIF
   NEXT

RETURN

STATIC PROCEDURE PlayerDeath()

   LOCAL i, b

   FOR EACH b IN s_aBombs
      hb_DispOutAt( b[ 2 ], b[ 1 ], " ", "W/N" )
   NEXT
   s_aBombs := {}
   IF s_lPb
      KillPlayerBullet()
   ENDIF

   PlaySfx( "playerdie", 5 )
   FOR i := 1 TO 14
      hb_DispOutAt( ROW_SHIP, s_nShipX, IIF( i % 2 == 1, "*#*", "#*#" ), IIF( i % 2 == 1, "R+/N", "Y+/N" ) )
      Inkey( 0.1 )
   NEXT
   hb_DispOutAt( ROW_SHIP, s_nShipX, "   ", "W/N" )

   s_nLives--
   s_lHud := .T.
   s_nShipX := FL + Int( FWID / 2 ) - 1
   HudAll()
   Inkey( 0.6 )
   hb_keyClear()

RETURN

// ---------------------------------------------------------------------
// Desenho
// ---------------------------------------------------------------------

STATIC FUNCTION Sprite( r, nFrame )

   DO CASE
   CASE r == 1
      RETURN IIF( nFrame == 0, "/M\", "\M/" )
   CASE r <= 3
      RETURN IIF( nFrame == 0, "{O}", "}O{" )
   ENDCASE

RETURN IIF( nFrame == 0, "<W>", ">W<" )

STATIC FUNCTION RowColor( r )

   DO CASE
   CASE r == 1
      RETURN "M+/N"
   CASE r <= 3
      RETURN "C+/N"
   ENDCASE

RETURN "G+/N"

STATIC PROCEDURE DrawFrame()

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S P A C E   I N V A D E R S   A R C A D E   by Jair Lima", 80 ), "N/W" )
   hb_DispOutAt( ROW_FLOOR, FL, Replicate( Chr( 205 ), FWID ), "G/N" )
   hb_DispOutAt( ROW_FLOOR + 1, 0, PadC( "SETAS/AD mover   ESPACO atirar   P pausa   M som   ESC sair", 80 ), "N+/N" )

RETURN

STATIC PROCEDURE DrawShip()
   hb_DispOutAt( ROW_SHIP, s_nShipX, "/^\", "G+/N" )
RETURN

STATIC PROCEDURE DrawAliens( nOldOy )

   LOCAL r, c

   FOR r := 1 TO NROWS
      hb_DispOutAt( nOldOy + 2 * ( r - 1 ), FL, Space( FWID ), "W/N" )
   NEXT
   FOR r := 1 TO NROWS
      FOR c := 1 TO NCOLS
         IF s_aAl[ r ][ c ]
            hb_DispOutAt( s_nOy + 2 * ( r - 1 ), s_nOx + ( c - 1 ) * 4, Sprite( r, s_nFrame ), RowColor( r ) )
         ENDIF
      NEXT
   NEXT

RETURN

STATIC PROCEDURE RenderAll()

   LOCAL i

   FOR i := ROW_UFO TO ROW_SHIP
      hb_DispOutAt( i, FL, Space( FWID ), "W/N" )
   NEXT
   DrawAliens( s_nOy )
   DrawBunkers()
   DrawShip()
   DrawShots()
   IF s_lUfo
      hb_DispOutAt( ROW_UFO, s_nUx, "<oOo>", "R+/N" )
   ENDIF

RETURN

STATIC PROCEDURE HudAll()

   LOCAL nHi := Max( s_nScore, s_aHi[ 1 ][ 2 ] )

   hb_DispOutAt( 1, 3, "SCORE", "W/N" )
   hb_DispOutAt( 1, 9, StrZero( Min( s_nScore, 999999 ), 6 ), "G+/N" )
   hb_DispOutAt( 1, 22, "HI-SCORE", "W/N" )
   hb_DispOutAt( 1, 31, StrZero( Min( nHi, 999999 ), 6 ), "Y+/N" )
   hb_DispOutAt( 1, 44, "WAVE", "W/N" )
   hb_DispOutAt( 1, 49, StrZero( Min( s_nLevel, 99 ), 2 ), "C+/N" )
   hb_DispOutAt( 1, 54, "LIVES", "W/N" )
   hb_DispOutAt( 1, 60, PadR( RTrim( Replicate( "/^\ ", s_nLives ) ), 19 ), "G+/N" )   // 5 vidas = cols 60-78
   s_lHud := .F.

RETURN

STATIC PROCEDURE Banner( cMsg, cClr )

   LOCAL c := "  " + cMsg + "  "
   LOCAL nCol := FL + Int( FWID / 2 ) - Int( Len( c ) / 2 )
   LOCAL nRow := 12

   hb_DispOutAt( nRow - 1, nCol - 1, Space( Len( c ) + 2 ), cClr )
   hb_DispOutAt( nRow, nCol - 1, " " + c + " ", cClr )
   hb_DispOutAt( nRow + 1, nCol - 1, Space( Len( c ) + 2 ), cClr )

RETURN

// ---------------------------------------------------------------------
// Recordes
// ---------------------------------------------------------------------

STATIC PROCEDURE LoadHi()

   LOCAL cFile := hb_DirBase() + HI_FILE
   LOCAL aLines, cLine, aTmp := {}

   IF File( cFile )
      aLines := hb_ATokens( StrTran( MemoRead( cFile ), Chr( 13 ), "" ), Chr( 10 ) )
      FOR EACH cLine IN aLines
         IF Len( cLine ) >= 5
            AAdd( aTmp, { Upper( Left( cLine, 3 ) ), Val( SubStr( cLine, 5 ) ) } )
         ENDIF
      NEXT
   ENDIF

   IF Len( aTmp ) >= 5
      ASize( aTmp, 5 )
      s_aHi := aTmp
   ELSE
      s_aHi := { { "JAL", 5000 }, { "ABC", 4000 }, { "INV", 3000 }, { "PAI", 2000 }, { "ZZZ", 1000 } }
   ENDIF

RETURN

STATIC FUNCTION SaveHi()

   LOCAL cTxt := "", a

   FOR EACH a IN s_aHi
      cTxt += a[ 1 ] + " " + LTrim( Str( a[ 2 ] ) ) + Chr( 13 ) + Chr( 10 )
   NEXT

RETURN hb_MemoWrit( hb_DirBase() + HI_FILE, cTxt )

STATIC PROCEDURE CheckHi( nScore )

   LOCAL nPos := 0, i, cName

   FOR i := 1 TO Len( s_aHi )
      IF nScore > s_aHi[ i ][ 2 ]
         nPos := i
         EXIT
      ENDIF
   NEXT

   IF nPos == 0 .OR. nScore <= 0
      RETURN
   ENDIF

   PlaySfx( "hiscore", 5 )
   cName := EnterInitials( nScore )
   hb_AIns( s_aHi, nPos, { cName, nScore }, .T. )
   ASize( s_aHi, 5 )
   IF ! SaveHi()
      hb_DispOutAt( 17, 0, PadC( "ATENCAO: recorde nao gravado (pasta sem permissao)", 80 ), "R+/N" )
      Inkey( 3 )
   ENDIF

RETURN

STATIC FUNCTION EnterInitials( nScore )

   LOCAL aCh := { 65, 65, 65 }, nPos := 1, k, i, cClr

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S P A C E   I N V A D E R S   A R C A D E   by Jair Lima", 80 ), "N/W" )
   hb_DispOutAt( 6, 0, PadC( "*** NEW HIGH SCORE ***", 80 ), "Y+/N" )
   hb_DispOutAt( 8, 0, PadC( "SCORE " + StrZero( Min( nScore, 999999 ), 6 ), 80 ), "G+/N" )
   hb_DispOutAt( 11, 0, PadC( "ENTER YOUR INITIALS", 80 ), "W/N" )
   hb_DispOutAt( 20, 0, PadC( "CIMA/BAIXO: letra   DIREITA/ENTER: proxima   ESQ: voltar", 80 ), "N+/N" )

   hb_keyClear()

   DO WHILE .T.

      FOR i := 1 TO 3
         cClr := IIF( i == nPos, "N/W", "W+/N" )
         hb_DispOutAt( 14, 35 + ( i - 1 ) * 4, " " + Chr( aCh[ i ] ) + " ", cClr )
      NEXT

      k := Inkey( 0 )

      DO CASE
      CASE k == K_UP
         aCh[ nPos ] := IIF( aCh[ nPos ] >= 90, 65, aCh[ nPos ] + 1 )
         PlaySfx( "pause", 5 )
      CASE k == K_DOWN
         aCh[ nPos ] := IIF( aCh[ nPos ] <= 65, 90, aCh[ nPos ] - 1 )
         PlaySfx( "pause", 5 )
      CASE k == K_LEFT
         nPos := Max( 1, nPos - 1 )
      CASE k == K_RIGHT .OR. k == K_ENTER
         IF nPos == 3
            EXIT
         ENDIF
         nPos++
         PlaySfx( "shoot", 5 )
      CASE ( k >= 65 .AND. k <= 90 ) .OR. ( k >= 97 .AND. k <= 122 )
         aCh[ nPos ] := Asc( Upper( Chr( k ) ) )
         PlaySfx( "shoot", 5 )
         IF nPos == 3
            EXIT
         ENDIF
         nPos++
      ENDCASE

   ENDDO

   hb_DispOutAt( 14, 43, " " + Chr( aCh[ 3 ] ) + " ", "W+/N" )
   PlaySfx( "wave", 5 )
   Inkey( 1 )

RETURN Chr( aCh[ 1 ] ) + Chr( aCh[ 2 ] ) + Chr( aCh[ 3 ] )

// ---------------------------------------------------------------------
// Som: WAV 8 bits (onda quadrada e ruido) tocado via winmm, com prioridade
// ---------------------------------------------------------------------

STATIC PROCEDURE InitSound()

   s_cTmp := GetEnv( "TEMP" )
   IF Empty( s_cTmp )
      s_cTmp := "."
   ENDIF
   IF ! Right( s_cTmp, 1 ) == "\"
      s_cTmp += "\"
   ENDIF

   MakeWav( "coin",     { { 988, 988, 70 }, { 1319, 1319, 330 } } )
   MakeWav( "start",    { { 523, 523, 90 }, { 659, 659, 90 }, { 784, 784, 90 }, { 1047, 1047, 260 } } )
   MakeWav( "shoot",    { { 1500, 350, 80 } } )
   MakeWav( "alienhit", { { 900, 150, 130, .T. } } )
   MakeWav( "bunker",   { { 400, 120, 45, .T. } } )
   MakeWav( "ufo",      { { 900, 1400, 70 }, { 1400, 900, 70 } } )
   MakeWav( "ufohit",   { { 880, 1760, 60 }, { 1760, 880, 60 }, { 880, 1760, 60 }, { 1760, 880, 120 } } )
   MakeWav( "playerdie", { { 900, 80, 1000, .T. } } )
   MakeWav( "march1",   { { 98, 98, 55 } } )
   MakeWav( "march2",   { { 87, 87, 55 } } )
   MakeWav( "march3",   { { 78, 78, 55 } } )
   MakeWav( "march4",   { { 73, 73, 55 } } )
   MakeWav( "wave",     { { 523, 523, 90 }, { 659, 659, 90 }, { 784, 784, 90 }, { 1047, 1047, 90 }, ;
                          { 784, 784, 90 }, { 1047, 1047, 320 } } )
   MakeWav( "gameover", { { 392, 392, 280 }, { 330, 330, 280 }, { 262, 262, 280 }, { 196, 196, 700 } } )
   MakeWav( "pause",    { { 600, 600, 50 }, { 400, 400, 80 } } )
   MakeWav( "hiscore",  { { 784, 784, 100 }, { 988, 988, 100 }, { 1175, 1175, 100 }, { 1568, 1568, 100 }, ;
                          { 1175, 1175, 100 }, { 1568, 1568, 400 } } )

RETURN

STATIC PROCEDURE MakeWav( cName, aNotes )

   LOCAL nRate := 11025
   LOCAL cData := "", a, i, nSamp, nPh, f, nAmp, nVal, cHdr, nMs := 0, nHold, nCur

   FOR EACH a IN aNotes
      nSamp := Int( a[ 3 ] * nRate / 1000 )
      nMs += a[ 3 ]
      nPh := 0
      nHold := 0
      nCur := 1
      FOR i := 1 TO nSamp
         f := a[ 1 ] + ( a[ 2 ] - a[ 1 ] ) * i / nSamp
         nAmp := 70 * ( 1 - 0.6 * i / nSamp )
         IF Len( a ) >= 4 .AND. a[ 4 ]
            IF nHold <= 0
               nCur := IIF( hb_RandomInt( 0, 1 ) == 0, 1, -1 )
               nHold := Max( 1, Int( nRate / Max( f, 40 ) / 2 ) )
            ENDIF
            nHold--
            nVal := 128 + nCur * nAmp
         ELSE
            nPh += f / nRate
            nPh -= Int( nPh )
            nVal := IIF( nPh < 0.5, 128 + nAmp, 128 - nAmp )
         ENDIF
         cData += Chr( Int( nVal ) )
      NEXT
   NEXT

   cHdr := "RIFF" + L2Bin( 36 + Len( cData ) ) + "WAVEfmt " + L2Bin( 16 ) + I2Bin( 1 ) + I2Bin( 1 ) + ;
      L2Bin( nRate ) + L2Bin( nRate ) + I2Bin( 1 ) + I2Bin( 8 ) + "data" + L2Bin( Len( cData ) )

   hb_MemoWrit( s_cTmp + "inv_" + cName + ".wav", cHdr + cData )
   s_hDur[ cName ] := nMs

RETURN

// canal unico: enquanto um efeito toca, so igual ou maior prioridade o substitui;
// um efeito de prioridade menor e DESCARTADO (nao entra em fila)
STATIC FUNCTION CanPlay( nPrio, nNow )
RETURN nNow >= s_nBusyUntil .OR. nPrio >= s_nBusyPrio

STATIC PROCEDURE PlaySfx( cName, nPrio )

   LOCAL nNow := hb_MilliSeconds()

   IF ! s_lSnd .OR. s_cTmp == NIL .OR. ! CanPlay( nPrio, nNow )
      RETURN
   ENDIF
   s_nBusyUntil := nNow + s_hDur[ cName ]
   s_nBusyPrio := nPrio
   wapi_PlaySound( s_cTmp + "inv_" + cName + ".wav", NIL, SND_FLAGS )

RETURN

// ---------------------------------------------------------------------
// Teclado direto (C embutido): estado real da tecla, so com a janela em foco
// ---------------------------------------------------------------------

#pragma BEGINDUMP

#define _WIN32_WINNT 0x0501
#include "hbapi.h"
#include <windows.h>
#include <mmsystem.h>

// Resolucao do timer: o Windows usa ~15,6 ms por padrao (hb_idleSleep(0.002) levou
// ~31 ms por chamada; com timeBeginPeriod(1) ainda ~21 ms, porque hb_idleSleep do
// Harbour dorme em passos grandes). Solucao: timeBeginPeriod(1) + Sleep() nativo.
HB_FUNC( TIMERRES )
{
   timeBeginPeriod( ( UINT ) hb_parni( 1 ) );
}

HB_FUNC( SLEEPMS )
{
   Sleep( ( DWORD ) hb_parni( 1 ) );
}

HB_FUNC( KEYDOWN )
{
   HWND hCon  = GetConsoleWindow();
   HWND hFg   = GetForegroundWindow();
   HWND hRoot = hCon ? GetAncestor( hCon, GA_ROOTOWNER ) : NULL;
   HB_BOOL bFocus = ( hFg != NULL ) && ( hFg == hCon || hFg == hRoot );

   hb_retl( bFocus && ( GetAsyncKeyState( hb_parni( 1 ) ) & 0x8000 ) != 0 );
}

#pragma ENDDUMP

// ---------------------------------------------------------------------
// Autoteste sem interface (invaders --selftest): regras deterministas
// ---------------------------------------------------------------------

STATIC PROCEDURE SelfTest()

   LOCAL nBad := 0, cLog := "", cWav, a, i, r, c, cMin, cMax, nOx0, nHit, nT0

   // ---- helper de verificacao ----
   LOCAL bChk := {| lOk, cMsg | cLog += IIF( lOk, "ok    ", "FALHA " ) + cMsg + hb_eol(), IIF( lOk, NIL, nBad++ ) }

   s_nLevel := 1
   s_nShipX := 40
   NewWave()

   // 1. curva de velocidade da formacao
   Eval( bChk, StepTicks( 55, 1 ) > StepTicks( 30, 1 ) .AND. StepTicks( 30, 1 ) > StepTicks( 5, 1 ), "StepTicks decresce com menos invasores" )
   Eval( bChk, StepTicks( 1, 1 ) == 2 .AND. StepTicks( 1, 9 ) == 2, "StepTicks nunca abaixo de 2 (ultimo invasor acertavel)" )
   Eval( bChk, StepTicks( 55, 5 ) < StepTicks( 55, 1 ), "ondas mais altas sao mais rapidas" )

   // 2. FindAlien: sprite de 3 colunas, 1 de espaco; fileiras alternadas
   s_nOx := 10
   s_nOy := 5
   a := FindAlien( 10, 5 )
   Eval( bChk, a != NIL .AND. a[ 1 ] == 1 .AND. a[ 2 ] == 1, "FindAlien canto superior esquerdo" )
   Eval( bChk, FindAlien( 12, 5 ) != NIL, "FindAlien terceira coluna do sprite" )
   Eval( bChk, FindAlien( 13, 5 ) == NIL, "FindAlien espaco entre invasores" )
   a := FindAlien( 14, 5 )
   Eval( bChk, a != NIL .AND. a[ 2 ] == 2, "FindAlien segunda coluna de invasores" )
   Eval( bChk, FindAlien( 10, 6 ) == NIL, "FindAlien linha vazia entre fileiras" )
   a := FindAlien( 10, 7 )
   Eval( bChk, a != NIL .AND. a[ 1 ] == 2, "FindAlien segunda fileira" )
   Eval( bChk, FindAlien( 9, 5 ) == NIL .AND. FindAlien( 10, 4 ) == NIL, "FindAlien fora da formacao" )
   s_aAl[ 2 ][ 1 ] := .F.
   Eval( bChk, FindAlien( 10, 7 ) == NIL, "FindAlien invasor morto" )
   s_aAl[ 2 ][ 1 ] := .T.

   // 3. pontos por fileira
   Eval( bChk, AlienPoints( 1 ) == 30 .AND. AlienPoints( 3 ) == 20 .AND. AlienPoints( 5 ) == 10, "pontuacao por fileira" )

   // 4. formacao vira na borda direita e desce
   s_nOx := FL + FWID - 1 - 42
   s_nOy := 5
   s_nDir := 1
   nOx0 := s_nOx
   Eval( bChk, StepFormation(), "desce ao tocar a borda direita" )
   Eval( bChk, s_nOy == 6 .AND. s_nDir == -1 .AND. s_nOx == nOx0, "borda direita: desceu 1, inverteu, nao andou" )
   // borda esquerda
   s_nOx := FL
   s_nDir := -1
   Eval( bChk, StepFormation() .AND. s_nDir == 1, "vira na borda esquerda" )
   // sem a coluna 1 a formacao pode ir mais a esquerda
   FOR r := 1 TO NROWS
      s_aAl[ r ][ 1 ] := .F.
   NEXT
   s_nOx := FL - 3
   s_nDir := -1
   Eval( bChk, ! StepFormation() .AND. s_nOx == FL - 4, "coluna esquerda morta libera espaco" )
   BoundsCols( @cMin, @cMax )
   Eval( bChk, cMin == 2 .AND. cMax == NCOLS, "BoundsCols apos matar coluna 1" )
   NewWave()

   // 5. invasao: chegou na linha da nave
   s_nOy := ROW_SHIP - 9                       // fileira de baixo na linha 21
   Eval( bChk, ! Landed(), "ainda nao pousou" )
   s_nOy := ROW_SHIP - 8                       // fileira de baixo na linha da nave
   Eval( bChk, Landed(), "fileira de baixo chegou na nave" )
   NewWave()
   FOR r := 4 TO 5
      FOR c := 1 TO NCOLS
         s_aAl[ r ][ c ] := .F.
      NEXT
   NEXT
   s_nOy := ROW_SHIP - 5                       // fileira 3 na linha 21
   Eval( bChk, ! Landed(), "pouso usa a fileira viva mais baixa (ainda no ar)" )
   s_nOy := ROW_SHIP - 4                       // fileira 3 na linha da nave
   Eval( bChk, Landed(), "pouso considera a fileira viva mais baixa" )
   NewWave()

   // 6. bunkers: cantos vazios, dano e destruicao
   Eval( bChk, ! BunkerHit( BunX( 1 ), BUN_TOP, 1 ), "canto arredondado do bunker e vazio" )
   Eval( bChk, BunkerHit( BunX( 1 ) + 3, BUN_TOP, 1 ) .AND. s_aBun[ 1 ][ 1 ][ 4 ] == 2, "tiro tira 1 de resistencia" )
   Eval( bChk, BunkerHit( BunX( 1 ) + 3, BUN_TOP, 2 ) .AND. s_aBun[ 1 ][ 1 ][ 4 ] == 0, "bomba tira 2 e destroi" )
   Eval( bChk, ! BunkerHit( BunX( 1 ) + 3, BUN_TOP, 1 ), "bloco destruido nao bloqueia mais" )
   Eval( bChk, ! BunkerHit( BunX( 1 ) + 3, BUN_TOP - 1, 1 ) .AND. ! BunkerHit( BunX( 1 ) + 3, BUN_TOP + 3, 1 ), "fora da altura do bunker" )
   Eval( bChk, ! BunkerHit( BunX( 1 ) + 8, BUN_TOP + 1, 1 ), "entre bunkers" )
   // invasor passando apaga o bunker
   NewWave()
   s_nOy := BUN_TOP - 2 * 1
   s_nOx := BunX( 2 )
   ClearBunkersUnderAliens()
   Eval( bChk, s_aBun[ 2 ][ 1 ][ 2 ] == 0 .AND. s_aBun[ 2 ][ 3 ][ 2 ] == 0 .AND. s_aBun[ 2 ][ 1 ][ 4 ] > 0, ;
      "invasor que passa destroi so os blocos sob ele (o vao entre sprites sobrevive)" )
   NewWave()

   // 7. nave atingida por bomba
   s_nShipX := 40
   Eval( bChk, ShipHit( 40, ROW_SHIP ) .AND. ShipHit( 42, ROW_SHIP ), "bomba na nave" )
   Eval( bChk, ! ShipHit( 43, ROW_SHIP ) .AND. ! ShipHit( 41, ROW_SHIP - 1 ) .AND. ! ShipHit( 39, ROW_SHIP ), "bomba fora da nave" )

   // 8. vidas extras: consome todos os marcos, respeita o limite de 5
   s_nLives := 3
   s_nExtra := 2000
   s_nScore := 4100
   s_lSnd := .F.
   CheckExtra()
   Eval( bChk, s_nLives == 5 .AND. s_nExtra == 6000, "dois marcos cruzados dao 2 vidas" )
   s_nScore := 12000
   CheckExtra()
   Eval( bChk, s_nLives == 5 .AND. s_nExtra == 14000, "limite de 5 vidas avanca o marco" )

   // 9. prioridade de som
   s_nBusyUntil := 1000
   s_nBusyPrio := 3
   Eval( bChk, ! CanPlay( 2, 500 ) .AND. CanPlay( 3, 500 ) .AND. CanPlay( 5, 500 ) .AND. CanPlay( 1, 1500 ), "prioridade de efeitos" )

   // 10. WAVs: cabecalho coerente
   s_lSnd := .T.
   InitSound()
   FOR EACH cWav IN { "coin", "start", "shoot", "alienhit", "bunker", "ufo", "ufohit", "playerdie", "march1", "march2", ;
                      "march3", "march4", "wave", "gameover", "pause", "hiscore" }
      a := hb_MemoRead( s_cTmp + "inv_" + cWav + ".wav" )
      i := Bin2L( SubStr( a, 41, 4 ) )
      Eval( bChk, Left( a, 4 ) == "RIFF" .AND. SubStr( a, 9, 4 ) == "WAVE" .AND. i == Len( a ) - 44 .AND. ;
         Bin2L( SubStr( a, 5, 4 ) ) == Len( a ) - 8 .AND. hb_HHasKey( s_hDur, cWav ) .AND. s_hDur[ cWav ] > 0, "WAV " + cWav )
   NEXT

   // 10b. tiro x bomba: simula o cruzamento (bomba anda a cada 3 ticks, tiro a cada 1)
   //      para todas as fases possiveis de defasagem; nenhuma pode atravessar
   s_lSnd := .F.
   nHit := 0
   FOR i := 0 TO 2
      s_aBombs := { { 20, 8 } }
      s_aFx := {}
      s_lPb := .T.
      s_nPbx := 20
      s_nPby := 21
      FOR r := 1 TO 40
         s_nPby--
         IF BulletBombHit()
            nHit++
            EXIT
         ENDIF
         IF ( r + i ) % 3 == 0
            s_aBombs[ 1 ][ 2 ]++
         ENDIF
      NEXT
   NEXT
   Eval( bChk, nHit == 3, "tiro nunca atravessa bomba (3 defasagens)" )
   s_aBombs := { { 20, 8 } }
   s_lPb := .T.
   s_nPbx := 21
   s_nPby := 9
   Eval( bChk, ! BulletBombHit(), "tiro em coluna vizinha nao acerta a bomba" )
   s_lPb := .F.

   // 10c. timer: 30 x SleepMs(2) tem que levar ~60-90 ms (e nao os ~600+ ms de hb_idleSleep)
   nT0 := hb_MilliSeconds()
   FOR i := 1 TO 30
      SleepMs( 2 )
   NEXT
   nT0 := hb_MilliSeconds() - nT0
   cLog += "info  30 x SleepMs(2) = " + hb_ntos( nT0 ) + " ms" + hb_eol()
   Eval( bChk, nT0 < 200, "TimerRes(1) + Sleep nativo: precisao de ~1-2 ms" )

   // 11. varredura aleatoria: bombas sempre nascem em celula de invasor vivo
   NewWave()
   FOR i := 1 TO 200
      s_aBombs := {}
      s_nLevel := 1 + i % 9
      FOR r := 1 TO 40
         EnemyFire()
      NEXT
      FOR EACH a IN s_aBombs
         c := FindAlien( a[ 1 ] - 1, a[ 2 ] - 1 )
         IF c == NIL
            nBad++
            cLog += "FALHA bomba fora de invasor" + hb_eol()
            EXIT
         ENDIF
      NEXT
      IF Len( s_aBombs ) > 6
         nBad++
         cLog += "FALHA excesso de bombas" + hb_eol()
      ENDIF
   NEXT
   cLog += "ok    varredura de 200 rodadas de tiro inimigo" + hb_eol()

   cLog += "falhas=" + hb_ntos( nBad ) + hb_eol()
   hb_MemoWrit( hb_DirBase() + "invaders_selftest.log", cLog )
   ErrorLevel( IIF( nBad == 0, 0, 1 ) )

RETURN
