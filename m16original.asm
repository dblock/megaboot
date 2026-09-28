.model small
.code
                org     0h                      ; .SYS

driver_suiv     dw      -1                      ;link with next driver's offset
                dw      -1                      ;link with next driver's segmen
attribut        dw      8004h                   ;device attribute word
req             dw      offset sys_request      ;offset to store request header
run             dw      offset init             ;offset for process interrupt <
nom_device      db      'MEGABOOT'

nreq:           or      es:word ptr [bx+3],0100h
nrun:           ret

end_tsr:

req_ofs         dw      ?
req_seg         dw      ?

sys_request proc far
        mov     cs:[req_ofs],bx
        mov     cs:[req_seg],es
        ret
sys_request endp

init proc far
        cld
        push    ax bx cx dx si di es ds         ;preserve registers
        push    cs
        pop     ds                              ;have the correct segment
                                                ;in ds
        call    init_driver                     ;initialize driver (.SYS)
        call    MEGABOOT

        pop     ds es di si dx cx bx ax         ;quit!
        ret                                     ;restore registers and end
init endp                                       ;since used from CONFIG.SYS
                                                ;do not end through int 21h
init_driver proc
        lds     bx,dword ptr cs:[req_ofs]       ;verify the DOS rubbish
        mov     word ptr [bx+14],0              ;version -> stay resident
        mov     word ptr [bx+16],cs             ;or not
        push    bx                              ;who uses DOS 3.2 ????
        mov     ah,30h
        int     21h                             ;HAS TO STAY RESIDENT BEFORE
        pop     bx                              ;DOS 3.2, cause otherwise
        cmp     al,3                            ;IT WILL GO CRAZY
        ja      no_tsr
        cmp     ah,21
        ja      no_tsr
        mov     word ptr [bx+14],offset end_tsr
        mov     cs:[run],offset nrun
        mov     cs:[req],offset nreq
   no_tsr:
        ret
init_driver endp

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

megaboot:
                push    bp ax bx cx dx es di ds si
                push    cs
                push    cs
                pop     ds
                pop     es

                mov     cx, ENDXOR-STARTXOR
                mov     di, offset STARTXOR
                mov     al, [xorval]
xorloop:        xor     ds:[di], al

                inc     di
                dec     cx
                jnz     xorloop
                jmp     startmegaboot

                db      ?
sizexor         dw      ENDXOR-STARTXOR
STARTXOR:
;=========================================

xorval          db      0
sign            db      'MEGABOOT'
ver             db      '0.90'

;=========================================

startmegaboot:  mov     dx, offset copyright
                mov     ah, 09h
                int     21h

                mov     si, offset cname
                call    locate                  ; trouve le segment du 1st I%
                mov     [premier%], di
                mov     si, offset endconfstr
                call    seglocate
                cmp     di, 0ffffh              ; %ENDCONFIG trouv‚ ?
                jnz     okmenu                  ; oui >> jmp menu
                mov     ah, 09h
                mov     dx, offset noendconfig
                int     21h
                jmp     fin
okmenu:
                mov     es:[di], '%0'           ; remplace I%ENDCONFIG
                mov     [endoffset], di         ; par 0%ENDCONFIG

search:
                mov     si, offset cname
                call    seglocate
                cmp     di, 0ffffh
                jz      donesearch              ; plus de config ?
                cmp     di, [endoffset]
                ja      donesearch              ; plus de config ?
                mov     al, es:[di+3]       ; es:[di+3] = lettre de la config
                mov     [c_name], al
                mov     al, '0'                 ; repmplace ' I%' par ' 0%'
                mov     es:[di+1], al

                xor     bp, bp
                mov     bx, di
                add     bx, 5
nomdanstab:     mov     dl, es:[bx]
                push    bx
                mov     bx, [configptr]
                add     bx, bp
                mov     byte ptr [configs+bx+pos_name],dl
                pop     bx
;                add     bx, offset configs
;                mov     byte ptr cs:[configptr+bx-2], dl
                inc     bp
                inc     bx                    ; fout les noms dans le tableau
                cmp     dl, 13
                jnz     nomdanstab

                mov     bx, [configptr]
                mov     al, es:[di+3]
                mov     [configs+bx], al
                mov     word ptr [configs+bx+pos_offset], di

                add     [configptr], long_configs
                inc     [nbconfigs]
                jmp     search

donesearch:     cmp     [nbconfigs], 0          ; au moins une config trouv‚e ?
                jnz     trouve_fin

                mov     ah, 09h
                mov     dx, offset aucune
                int     21h
                jmp     fin

trouve_fin:
                mov     bx, [configptr]
                mov     ax, [endoffset]
                dec     ax
                mov     word ptr [configs+bx+pos_offset], ax

                mov ax, 0305h                    ; typematic rate
                mov bx, 4h
                int 16h

                call    displaymenu

                mov     [choixconf], al
                mov     [setgoto], al

                cmp     [HideShit], 1
                jnz     startmega
                push    es ds
                mov     ax, 0b800h
                mov     es, ax
                mov     ds, ax
                xor     si, si
                mov     di, 80*50*2
                mov     cx, 80*50*2
                rep     movsb
                pop     ds es

                mov     dx, 3d4h
                mov     al, 0ch
                mov     ah, (80*50) shr 8
                out     dx, ax
                mov     al, 0dh
                mov     ah, (80*50) and 0ffh
                out     dx, ax

;---------- START MEGABOOOOOT'S MAGOUILLES ! (BOOT) ----

startmega:      mov     cx, word ptr [configs+bx+long_configs+pos_offset]
                sub     cx, word ptr [configs+bx+pos_offset] ; longueur en cx

                push    ds si es di
                mov     di, [premier%]
                inc     di
                mov     si, word ptr [configs+bx+pos_offset]
                inc     si
                push    es
                pop     ds
                rep     movsb                ; COPIE LA CONFIG

                mov     cx, [endoffset]      ; <--- Loom: c t cette ligne la
                sub     cx, di                            ; ch'tite couille.
                mov     al, 10
                rep     stosb                ; REMPLIS DE 10 (LF)

                push    cs
                pop     ds
                mov     si, offset setconfig
                mov     di, endoffset
                mov     cx, 13
                rep     movsb                ; MET LE DERNIER SET CONFIG=

                pop     di es si ds

fin:            pop     si ds di es dx cx bx ax bp
                ret

;=========================================================================
displaymenu:                                    ; affiche le menu
                push    es di ds si cx bp
                mov     ah, 02h
                xor     bh, bh
                mov     dx, 0ff00h
                int     10h                     ; enleve le cursor
                push    cs
                pop     ds
                mov     ax, 0b800h
                mov     es, ax
                xor     di, di
                mov     si, offset binary
                mov     cx, 80*25*2
                rep     movsb
                mov     ah, 02h
                xor     bh, bh

                call    menuproc

                pop     bp cx si ds di es
                ret

;=========================================================================
menuproc:       push    cx dx ds si es di bp  ; LE menu

                call    menuloop
                jmp     redemande

menuloop:
                mov     bx, 0
                mov     al, Color
menuloop1:
                mov     cl, [PosX]
                mov     ch, [PosY]
                add     ch, bl
                push    bx
                add     bx, [decalage]
                call    printchoix
                pop     bx
                inc     bx
                cmp     bl, [TailleY]
                jae     endmenuloop
                cmp     bl, [nbconfigs]
                jae     endmenuloop
                jmp     menuloop1
endmenuloop:    ret
;----

redemande:
                mov     bl, [PosMenu]
                xor     bh, bh
                mov     al, XColor
                mov     cl, [PosX]
                mov     ch, [PosY]
                add     ch, bl
                push    bx
                add     bx, [decalage]
                call    printchoix
                pop     bx

                call    fleches
                mov     ah, 07h                 ; read a char
                int     21h

                push    ax
                mov     bl, [PosMenu]
                xor     bh, bh
                mov     al, Color
                mov     cl, [PosX]
                mov     ch, [PosY]
                add     ch, bl
                push    bx
                add     bx, [decalage]
                call    printchoix
                pop     bx
                pop     ax

                cmp     al, 0                   ; charactere etendu ?
                jnz     nonzero

                mov     ah, 07h                 ; read le truc etendu
                int     21h

                cmp     al, 'H'
                jnz     non_1
                mov     al, [PosMenu]
                add     al, byte ptr [decalage]
                cmp     al, 0
                jz      non_1
                cmp     [PosMenu], 0
                jz      decale1
                dec     [PosMenu]
                jmp     redemande
decale1:
                dec     [decalage]
                call    menuloop
                jmp     redemande

non_1:
                cmp     al, 'P'
                jnz     non_2
                mov     al, [nbconfigs]
                sub     al, byte ptr [decalage]
                dec     al
                cmp     [PosMenu], al
                jz      non_2
                mov     al, [TailleY]
                dec     al
                cmp     [PosMenu], al
                jz      decale2
                inc     [PosMenu]
                jmp     redemande
decale2:
                inc     [decalage]
                call    menuloop
                jmp     redemande
non_2:
                jmp     redemande

nonzero:
                cmp     al, 13
                jz      enter_escape
                cmp     al, 27
                jz      enter_escape
;--------
                cmp     al, 'a'
                jna     ok_maj
                cmp     al, 'z'
                jnb     ok_maj
                sub     al, 'a'-'A'            ; converti en majuscule
ok_maj:
                mov     cl, [nbconfigs]
                xor     ch, ch
                xor     bx, bx
askloop:
                cmp     [configs+bx], al
                jz      choix_ok
                add     bx, long_configs
                dec     cx
                jnz     askloop       ; cherche dans toutes les conf stock‚es
                              ; pour voire si la touche correspond a une conf
                jmp     redemande

choix_ok:                                       ; la configuration existe!
                jmp     stopaff

;--------
enter_escape:   mov     al, [PosMenu]
                add     al, byte ptr [decalage]
                mov     dl, long_configs
                mul     dl
                mov     bx, ax
                mov     al, byte ptr [configs+bx]
                jmp     stopaff
;----
stopaff:
                push    ax bx
                mov     dl, long_configs
                mov     ax, bx
                div     dl
                mov     bx, ax

                cmp     ax, [decalage]
                jb      end_display
                mov     cx, [decalage]
                add     cl, [TailleY]
                cmp     al, cl
                jae     end_display

                mov     al, XColor
                mov     cl, [PosX]
                mov     ch, [PosY]
                sub     bl, byte ptr [decalage]
                add     ch, bl
                push    bx
                add     bx, [decalage]
                call    printchoix
                pop     bx

end_display:    xor     bh, bh                    ;passe a la ligne
                xor     dl, dl
                mov     dh, 23
                mov     ah, 02h
                int     10h
                push    cs
                pop     ds
                mov     dx, offset return
                mov     ah, 09h
                int     21h

                pop     bx ax
                pop     bp di es si ds dx cx
                ret       ; la configuration est maintenant dans al et bx

PosMenu         db      0
decalage        dw      0

;=========================================================================
fleches:                  ; affiche les fleches si besoin
                push    ax bx cx dx es
                mov     ax, 0b800h
                mov     es, ax
                cmp     [decalage], 0
                jz      pas_haut
                mov     dl, [PosY]
                mov     cl, [PosX]
                mov     al, 80*2
                mul     dl
                xor     ch, ch
                shl     cx, 1
                add     ax, cx              ; now offset de mem video dans AX
                mov     cl, [TailleX]
                xor     ch, ch
                add     ax, cx
                add     ax, cx
                sub     ax, 4
                mov     bx, ax
                mov     byte ptr es:[bx], ''
pas_haut:
                mov     al, byte ptr [decalage]
                add     al, [TailleY]
                cmp     al, [nbconfigs]
                jae     pas_bas

                mov     dl, [PosY]
                add     dl, [TailleY]
                dec     dl
                mov     cl, [PosX]
                mov     al, 80*2
                mul     dl
                xor     ch, ch
                shl     cx, 1
                add     ax, cx              ; now offset de mem video dans AX
                mov     cl, [TailleX]
                xor     ch, ch
                add     ax, cx
                add     ax, cx
                sub     ax, 4
                mov     bx, ax
                mov     byte ptr es:[bx], ''

pas_bas:
                pop     es dx cx bx ax
                ret

;=========================================================================
printchoix:         ; affiche un string (al=couleur, bx=numero, cl=x, ch=y)
                push    ax bx cx dx
                push    cs
                pop     es
                mov     [pc_color], al
                mov     dl, ch
                mov     al, 80*2
                mul     dl
                xor     ch, ch
                shl     cx, 1
                add     ax, cx              ; now offset de mem video dans AX
                push    ax

                mov     di, offset pc_str
                mov     cx, 80
                mov     al, 0
                rep     lodsb                   ; refout le str a 0

                mov     ax, long_configs
                mov     dx, bx
                mul     dx
                mov     bx, ax
                add     bx, offset configs
                mov     al, [bx]
                mov     [pc_str+1], al     ; fout la lettre de la config
                mov     [pc_str+3], ':'    ; fout le ":"

                mov     si, bx
                add     si, pos_name
                mov     di, offset pc_str+5
                mov     cx, (long_configs-pos_name)
                rep     movsb              ; fout le nom

                mov     ax, 0b800h
                mov     es, ax
                pop     bx

                mov     cl, [TailleX]
                xor     bp, bp
affloop:
                mov     ah, [pc_color]
                mov     al, [pc_str+bp]
                cmp     al, 32
                jnb     aff_c1
                mov     al, 0
aff_c1:         mov     es:[bx], ax
                inc     bx
                inc     bx
                inc     bp
                dec     cl
                jnz     affloop

                pop     dx cx bx ax
                ret
pc_color        db      ?
pc_str          db      80 dup (0)

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

locate:         push    ax      ; input ds:[si]   output  es:[di]
                push    bx
                push    dx

                mov     al, ds:[si]
                mov     cs:[long], al
                xor     ah, ah
                add     si, ax      ; change le pointeur a la fin du string

                xor     dx, dx
@loopseg:       mov     es, dx
                mov     di, 10h
@loopofs:
                xor     bh, bh
                mov     bl, cs:[long]
                dec     bl
@loopstr:
                push    si
                sub     si, bx
                mov     al, ds:[si]
                pop     si
                cmp     es:[di+bx], al
                jnz     @pasegal
                dec     bx
                cmp     bx, 0ffffh
                jnz     @loopstr
;-
                jmp     @trouve
@pasegal:
                dec     di
                jnz     @loopofs

                inc     dx
                cmp     dx, 09fffh
                jnz     @loopseg

                mov     di, 0ffffh

@trouve:
                pop     dx
                pop     bx
                pop     ax
                ret
long            db      0

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

seglocate:      push    ax        ; input ds:[si] + es  /  output  es:[di]
                push    bx
                push    dx

                mov     al, ds:[si]
                mov     cs:[llong], al
                xor     ah, ah
                add     si, ax      ; change le pointeur a la fin du string

                mov     di, 0
@@loopofs:
                xor     bh, bh
                mov     bl, cs:[llong]
                dec     bl
@@loopstr:
                push    si
                sub     si, bx
                mov     al, ds:[si]
                pop     si
                cmp     es:[di+bx], al
                jnz     @@pasegal
                dec     bx
                cmp     bx, 0ffffh
                jnz     @@loopstr
;-
                jmp     @@trouve
@@pasegal:
                inc     di
                cmp     di, 0ffffh
                jnz     @@loopofs

@@trouve:
                pop     dx
                pop     bx
                pop     ax
                ret
llong           db      0

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

configptr       dw      0
nbconfigs       db      0
return          db      13, 10, 10, '$'
endconfstr      db      11,'GIFNOCDNE%I'
cname           db      3,'%I', 0ah
setconfig       db      10,10,'VCONFIG='         ; set config=X
setgoto         db      ?, 10, 10                ; 0=end of config.sys
copyright       db      'MEGABOOT 0.9 (C) 1996, David Jilli, DSF Productions.',13,10,'$'
noendconfig     db      13,10,7,'Pas d''INSTALL %ENDCONFIG dans le fichier CONFIG.SYS!',13,10,'$'
pasc            db      13,10,7,'Cette configuration n''exitste pas.',13,10,'$'
aucune          db      13,10,7,'Aucune configuration trouv‚e.',13,10,'$'
entrez          db      13,10,10,'Choix : $'
erreur          db      13,10,7,'Erreur survenue durant la lecture des configurations multiple.$'
configstr       db      ''
c_name          db      ?, ' : $'
choixconf       db      ?
premier%        dw      ?
endoffset       dw      ?

ENDXOR:

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

exeload          db    13,10, 'Tapez LISEZMOI pour l''aide.',13,10,'$'

exepart:
                mov     ah, 09h
                mov     dx, offset exeload
                push    cs
                pop     ds
                int     21h
                mov     ax, 4c00h
                int     21h

configs         db      90*255 dup (0)        ;   0 : lettre
                                              ; 1-2 : offset
                                              ;  3+ : description

long_configs    equ     90
pos_lettre      equ     0
pos_offset      equ     8
pos_name        equ     10

TailleX         db      30
TailleY         db      10
Color           db      11+16*0
XColor          db      15+16*4
HideShit        db      0                     ; cache ? 0=non 1=oui
PosX            db      45                    ; position X du menu
PosY            db      4                     ; position Y du menu
binary          db      4000 dup (0)          ; dessin binaire


END exepart                                   ; pour fixer le point d'entree
                                              ; de exepa 