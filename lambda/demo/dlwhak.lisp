;;; -*- Mode:LISP; Package:HACKS; Base:8; Readtable:ZL -*-

;; User documentation:
;;; HACKS:TEST-PARC-WINDOW &optional (LABEL "This is a label.")
;;;     gets corners from the mouse and creates a PARC-labelled window.,
;;; HACKS:SPLINES draw splines on TERMINAL-IO.  You hit the left
;;;     button to set the next knot, and other buttons to draw it.  CTRL/ABORT to quit.
;;;     The middle button is relaxed open splines.
;;;     The right button is cyclic closed splines.
;;; (SETQ BASE 'TALLY) will cause numbers to come out in tally-mark notation.
;;;     This only works right if the default font is CPTFONT in the window.
;;; (TVBUG) from any Lisp Listener will walk a TV bug up from the bottom center.
;;;     It will go until it hits the top or until you type a character.  It runs
;;;     in "real time" mode.

(DEFFLAVOR PARC-LABEL-MIXIN () (TV:LABEL-MIXIN)
  (:INCLUDED-FLAVORS TV:WINDOW)
  (:DOCUMENTATION :MIXIN "Label at the top, with a box around it.
If the label is a string or defaults to the name, it is at the top.
When combined with BORDERS-MIXIN, the label will be surrounded by a box.
TOP-BOX-LABEL-MIXIN assumes borders will be outside, but this assumes
they will be inside."))

;;; Tell margin recomputation that there is an extra line, for the box.
(DEFMETHOD (PARC-LABEL-MIXIN :PARSE-LABEL-SPEC) (SPEC LM TM RM BM)
  (MULTIPLE-VALUE (SPEC LM TM RM BM)
    ;>> BARF ********************
    (FUNCALL #'(:METHOD TV:LABEL-MIXIN :PARSE-LABEL-SPEC) ':PARSE-LABEL-SPEC
             SPEC LM TM RM BM T))
  (AND SPEC (SETQ TM (+ TM 1)))
  (VALUES SPEC LM TM RM BM))

;;; Draw a box around the label.  Only draw three sides; the top border forms
;;; the bottom.
(DEFMETHOD (PARC-LABEL-MIXIN :AFTER :DRAW-LABEL) (SPEC LEFT TOP RIGHT BOTTOM)
  (LET* ((WIDTH (- RIGHT LEFT))
         (HEIGHT (- BOTTOM TOP))
         (LABEL-LENGTH (MIN (1+ (SEND SELF :STRING-LENGTH (TV:LABEL-STRING SPEC)))
                            WIDTH)))
    (TV:SHEET-FORCE-ACCESS (SELF)
      (TV:PREPARE-SHEET (SELF)
        (TV:%DRAW-RECTANGLE 1 (1+ HEIGHT) LEFT TOP TV:CHAR-ALUF SELF)
        (TV:%DRAW-RECTANGLE LABEL-LENGTH 1 LEFT TOP TV:CHAR-ALUF SELF)
        (TV:%DRAW-RECTANGLE 1 (1+ HEIGHT) (+ LEFT LABEL-LENGTH) TOP TV:CHAR-ALUF SELF)))))

;;; Must add 1 to top and left of string, to make room for the box.
(DEFMETHOD (PARC-LABEL-MIXIN :DRAW-LABEL) (SPEC LEFT TOP RIGHT BOTTOM)
  (declare (ignore BOTTOM))
  (AND SPEC
       (SEND SELF ':STRING-OUT-EXPLICIT (TV:LABEL-STRING SPEC)
             (1+ LEFT) (1+ TOP) (- RIGHT LEFT) NIL
             (TV:LABEL-FONT SPEC) TV:CHAR-ALUF 0 NIL NIL)))

(DEFFLAVOR PARC-WINDOW () (PARC-LABEL-MIXIN TV:WINDOW))

(COMPILE-FLAVOR-METHODS PARC-WINDOW)

(DEFVAR TEST-PARC-WINDOW)

(DEFUN TEST-PARC-WINDOW (&OPTIONAL (LABEL "This is a label."))
  (SETQ TEST-PARC-WINDOW
        (MAKE-INSTANCE 'PARC-WINDOW
                       :EDGES-FROM ':MOUSE
                       :EXPOSE-P T
                       :LABEL LABEL
                       :BLINKER-P NIL)))

;;; Get a bunch of points from the user.
;;; Do graphics on WINDOW.  PX and PY are arrays which this function pushes
;;; pairs of coordinates onto.  If CLOSE-P, it will also push the first point
;;; onto the end.  It zeroes the fill pointers of the arrays.  It echoes
;;; by putting dots at each point.  You click left to put a point and click
;;; anything else to get out.
(DEFUN MOUSE-DRAW-SPLINE-CURVE (WINDOW PX PY DOCUMENTATION-STRING)
  (SETF (FILL-POINTER PX) 0)
  (SETF (FILL-POINTER PY) 0)
  (MULTIPLE-VALUE-BIND (DX DY)
      (TV:SHEET-CALCULATE-OFFSETS WINDOW TV:MOUSE-SHEET)
    (SETQ DX (+ DX (TV:SHEET-INSIDE-LEFT WINDOW))
          DY (+ DY (TV:SHEET-INSIDE-TOP WINDOW)))
    (TV:WITH-MOUSE-GRABBED-ON-SHEET (WINDOW)
      (LET-GLOBALLY ((TV:WHO-LINE-MOUSE-GRABBED-DOCUMENTATION DOCUMENTATION-STRING))
        (DO ((X) (Y) MOUSE-FOO)
            (NIL)
          (PROCESS-WAIT "Mouse up" (LAMBDA () (ZEROP TV:MOUSE-LAST-BUTTONS)))
          (PROCESS-WAIT "Mouse down"
                        #'(LAMBDA (WINDOW LOC)
                            (OR (SEND WINDOW :LISTEN)
                                (NOT (ZEROP (SETF (CONTENTS LOC) TV:MOUSE-LAST-BUTTONS)))))
                        WINDOW
                        (LOCF MOUSE-FOO))
          (SEND WINDOW :TYI-NO-HANG)            ;Let Abort work.
          (OR (= MOUSE-FOO 1) (RETURN MOUSE-FOO))
          (SETQ X (- TV:MOUSE-X DX) Y (- TV:MOUSE-Y DY))
          (IF (NOT (AND (< -1 X (TV:SHEET-INSIDE-WIDTH WINDOW))
                        (< -1 Y (TV:SHEET-INSIDE-HEIGHT WINDOW))))
              (BEEP)                            ;Mouse is outside the window's interior.
            (SEND WINDOW :DRAW-RECTANGLE 3 3 (1- X) (1- Y) TV:ALU-XOR)
            (VECTOR-PUSH-EXTEND X PX)
            (VECTOR-PUSH-EXTEND Y PY)))))))

;;; Simple test program
(DEFUN SPLINES (&OPTIONAL (WINDOW *TERMINAL-IO*) (WIDTH 4) (ALU TV:ALU-IOR) (PRECISION 20.))
  (SEND WINDOW :CLEAR-WINDOW)
  ;; who cares about discarding these?   That's what garbage collectors are for
  (LET ((MOUSE-PX (MAKE-ARRAY 100. :FILL-POINTER 0))
        (MOUSE-PY (MAKE-ARRAY 100. :FILL-POINTER 0))
        ;(MOUSE-CX (MAKE-ARRAY (* PRECISION 100.) :FILL-POINTER 0))
        ;(MOUSE-CY (MAKE-ARRAY (* PRECISION 100.) :FILL-POINTER 0))
        )
    (DO () (())
      (LET ((BUTTONS (MOUSE-DRAW-SPLINE-CURVE WINDOW MOUSE-PX MOUSE-PY
             "Left: Set point.  Middle: Draw open curve.  Right: Draw closed curve.  Abort exits.")))
        (LET ((LEN (ARRAY-ACTIVE-LENGTH MOUSE-PX)))
          (DOTIMES (N LEN)
            (SEND WINDOW :DRAW-RECTANGLE 3 3 (1- (AREF MOUSE-PX N)) (1- (AREF MOUSE-PY N))
                                         TV:ALU-XOR))
;           (SEND WINDOW :DRAW-CHAR FONTS:CPTFONT #/  (AREF MOUSE-PX N) (AREF MOUSE-PY N)
;                                   TV:ALU-XOR))
          (COND ((< LEN 2)
                 (SEND WINDOW :BEEP))
                ((= BUTTONS 2)
                 (SEND WINDOW :DRAW-CUBIC-SPLINE MOUSE-PX MOUSE-PY
                                                 PRECISION WIDTH ALU :RELAXED))
                (T
                 (VECTOR-PUSH-EXTEND (AREF MOUSE-PX 0) MOUSE-PX)
                 (VECTOR-PUSH-EXTEND (AREF MOUSE-PY 0) MOUSE-PY)
                 (SEND WINDOW :DRAW-CUBIC-SPLINE MOUSE-PX MOUSE-PY
                                                 PRECISION WIDTH ALU :CYCLIC))))))))

(DEFVAR *SPLINES-WINDOW* NIL "Window used by SPLINES-IN-WINDOW")

(DEFUN SPLINES-IN-WINDOW ()
  (IF (NULL *SPLINES-WINDOW*)
      (MULTIPLE-VALUE-BIND (LEFT TOP RIGHT BOTTOM)
          (SEND TV:MOUSE-SHEET :EDGES)
        (LET ((FACTOR 10.))
          (SETQ *SPLINES-WINDOW*
                (MAKE-INSTANCE 'TV:WINDOW
                               :SUPERIOR TV:MOUSE-SHEET
                               :LEFT (+ LEFT FACTOR)
                               :TOP (+ TOP FACTOR)
                               :RIGHT (- RIGHT FACTOR)
                               :BOTTOM (- BOTTOM FACTOR)
                               :BORDERS 4
                               :BLINKER-P NIL
                               :LABEL "Spline-drawing Window")))))
  (UNWIND-PROTECT
      (PROGN
        (SEND *SPLINES-WINDOW* :SET-PROCESS CURRENT-PROCESS)
        (SEND *SPLINES-WINDOW* :SELECT)
        (SPLINES *SPLINES-WINDOW*))
    (SEND *SPLINES-WINDOW* :DEACTIVATE)))

(DEFDEMO "Splines" "Lets you draw open and closed cubic splines with the mouse."
  (SPLINES-IN-WINDOW))

(DEFPROP :TALLY TALLY-PRINC SI:PRINC-FUNCTION)

(DEFUN TALLY-PRINC (N STREAM)
  (IF (NOT (BOUNDP 'FONTS:TALLY))
      (LOAD "SYS: FONTS; TALLY QFASL" :PACKAGE 'FONTS))
  (COND ((OPERATION-HANDLED-P STREAM :SET-FONT-MAP)
         (LET ((OLD-FONT-MAP (SEND STREAM :FONT-MAP))
               (OLD-FONT (SEND STREAM ':CURRENT-FONT)))
           (UNWIND-PROTECT
               (PROGN
                 (SEND STREAM :SET-FONT-MAP '(FONTS:CPTFONT FONTS:TALLY))
                 (SEND STREAM :SET-CURRENT-FONT 1)
                 (TALLY-PRINT (IF (BIGP N) N (- N)) STREAM))
             (SEND STREAM :SET-FONT-MAP OLD-FONT-MAP)
             (SEND STREAM :SET-CURRENT-FONT OLD-FONT))))
        (T
         (TALLY-BOMB (IF (BIGP N) N (- N)) STREAM))))

(DEFUN TALLY-PRINT (N STREAM)
  (DOTIMES (I (TRUNCATE N 5))
    (SEND STREAM :TYO #/5))
  (DOTIMES (I (\ N 5))
    (SEND STREAM :TYO #/1)))

(DEFUN TALLY-BOMB (N STREAM)
  (LET ((*PRINT-BASE* 10.))
    (PRINC N STREAM)))

;(DEFUN TVBUG (&OPTIONAL (SLOWNESS 10000.) (WINDOW STANDARD-OUTPUT))
;  (IF (NOT (BOUNDP 'FONTS:TVBUG))
;      (LOAD "SYS: FONTS; TVBUG"))
;  (CATCH 'CUT-IT-OUT
;    (MULTIPLE-VALUE-BIND (WIDTH HEIGHT)
;       (SEND WINDOW :INSIDE-SIZE)
;      (WITH-REAL-TIME
;       (DO ((X (truncate WIDTH 2))
;            (Y (- HEIGHT 33.)))
;           ((MINUSP Y))
;         (DOLIST (CHAR '(#/A #/B #/C #/D))
;           (SEND WINDOW :DRAW-CHAR FONTS:TVBUG CHAR X Y TV:ALU-XOR)
;           (DOTIMES (I SLOWNESS))
;           (FUNCALL WINDOW :DRAW-CHAR FONTS:TVBUG CHAR X Y TV:ALU-XOR)
;           (IF (SEND WINDOW :TYI-NO-HANG)
;               (THROW 'CUT-IT-OUT NIL))
;           (SETQ Y (1- Y))))))))

;; Note: when array index order is changed,
;; the saved arrays in TVBGAR will need to be transposed.

(DEFVAR *TVBUG-ARRAYS*) ;List of the arrays of the bug
(DEFVAR *TVBUG-XORS*)   ;Boolean first differences of the above
(DEFUN TVBUG (&OPTIONAL (SLOWNESS 500.) (WINDOW *STANDARD-OUTPUT*))
  (IF (NOT (BOUNDP '*TVBUG-ARRAYS*))
      (LOAD "SYS: DEMO; TVBGAR"))
  (IF (NOT (BOUNDP '*TVBUG-XORS*))
      (SETQ *TVBUG-XORS*
            (LOOP FOR (A1 A2) ON *TVBUG-ARRAYS*
                  AS XOR = (MAKE-PIXEL-ARRAY 40 41 :ELEMENT-TYPE 'BIT)
               DO (BITBLT TV:ALU-SETA 40 40 A1 0 0 XOR 0 1)
                  (BITBLT TV:ALU-XOR 40 40 (OR A2 (CAR *TVBUG-ARRAYS*)) 0 0 XOR 0 0)
               COLLECT XOR)))
  (MULTIPLE-VALUE-BIND (WIDTH HEIGHT)
      (SEND WINDOW :INSIDE-SIZE)
    (WITH-REAL-TIME
      (LET ((X (TRUNCATE WIDTH 2)) (Y (- HEIGHT 33.)) (PHASE 0))
        (SEND WINDOW ':BITBLT TV:ALU-XOR 40 40 (FIRST *TVBUG-ARRAYS*) 0 0 X Y)
        (BLOCK LUPO
          (DO () ((SEND WINDOW :TYI-NO-HANG))
            (DOLIST (XOR *TVBUG-XORS*)
              (SETQ Y (1- Y))
              (FUNCALL WINDOW ':BITBLT TV:ALU-XOR 40 41 XOR 0 0 X Y)
              (SETQ PHASE (\ (1+ PHASE) (LENGTH *TVBUG-XORS*)))
              (DOTIMES (I SLOWNESS))
              (IF (ZEROP Y) (RETURN-FROM LUPO)))))
        (SEND WINDOW :BITBLT TV:ALU-XOR 40 40 (NTH PHASE *TVBUG-ARRAYS*) 0 0 X Y)))))

(DEFDEMO "TV bug" "Display bugs in windows." (TVBUG))
