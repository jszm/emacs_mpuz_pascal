;;; mpuz_parity_emacs.el --- Emit deterministic mpuz.el parity snapshots -*- lexical-binding: t; -*-

;; This file is loaded by ../parity.ps1 after GNU Emacs' lisp/play/mpuz.el.

(require 'cl-lib)

(defconst mpuz-parity-mapping-a [9 1 5 0 8 2 7 3 6 4])
(defconst mpuz-parity-mapping-b [3 7 2 9 0 6 1 8 4 5])
(defconst mpuz-parity-mapping-c [0 2 4 6 8 1 3 5 7 9])

(defconst mpuz-parity-draw-stream-a [2 5 1 7 0 3 1 0 1 0 233 1 0 0 2])
(defconst mpuz-parity-draw-stream-b [9 0 8 1 6 2 4 1 0 0 874 6 4 4 5])

(setq inhibit-message t
      mpuz-silent t)

(defvar mpuz-parity-active-draws nil)
(defvar mpuz-parity-active-draw-index 0)

(defun mpuz-parity-random (limit)
  (when (>= mpuz-parity-active-draw-index (length mpuz-parity-active-draws))
    (error "parity draw stream exhausted"))
  (prog1
      (% (aref mpuz-parity-active-draws mpuz-parity-active-draw-index) limit)
    (setq mpuz-parity-active-draw-index (1+ mpuz-parity-active-draw-index))))

(defun mpuz-parity-add-square (digit row col)
  (aset mpuz-board digit
        (append (aref mpuz-board digit) (list (cons row col)))))

(defun mpuz-parity-put-number (number row columns)
  (dolist (column columns)
    (let ((digit (% number 10)))
      (setq number (/ number 10))
      (mpuz-parity-add-square digit row column))))

(defun mpuz-parity-put-fixture-numbers (a b1 b2)
  (let ((c (* a b2))
        (d (* a b1)))
    (mpuz-parity-put-number a 2 '(9 7 5))
    (mpuz-parity-put-number (+ (* b1 10) b2) 4 '(9 7))
    (mpuz-parity-put-number c 6 '(9 7 5 3))
    (mpuz-parity-put-number d 8 '(7 5 3 1))
    (mpuz-parity-put-number (+ c (* d 10)) 10 '(9 7 5 3 1))))

(defun mpuz-parity-reset-fixture (mapping a b1 b2)
  (setq mpuz-in-progress t
        mpuz-solve-when-trivial t
        mpuz-allow-double-multiplicator nil
        mpuz-nb-errors 0
        mpuz-nb-completed-games 0
        mpuz-nb-cumulated-errors 0)
  (fillarray mpuz-board nil)
  (fillarray mpuz-found-digits nil)
  (fillarray mpuz-trivial-digits nil)
  (dotimes (digit 10)
    (let ((letter (aref mapping digit)))
      (aset mpuz-digit-to-letter digit letter)
      (aset mpuz-letter-to-digit letter digit)))
  (mpuz-parity-put-fixture-numbers a b1 b2))

(defun mpuz-parity-reset-fixture-a ()
  (mpuz-parity-reset-fixture mpuz-parity-mapping-a 358 4 7))

(defun mpuz-parity-bool-text (value)
  (if value "t" "nil"))

(defun mpuz-parity-flags-text (flags)
  (mapconcat (lambda (value) (mpuz-parity-bool-text value)) flags ""))

(defun mpuz-parity-average-text ()
  (format "%.2f"
          (if (zerop mpuz-nb-completed-games)
              0
            (/ (+ 0.0 mpuz-nb-cumulated-errors)
               mpuz-nb-completed-games))))

(defun mpuz-parity-mapping-text ()
  (mapconcat (lambda (value) (number-to-string value)) mpuz-digit-to-letter ""))

(defun mpuz-parity-digit-appears-p (digit row col)
  (let ((squares (aref mpuz-board digit)))
    (and squares
         (if (zerop row)
             t
           (if (< col 0)
               (assq row squares)
             (member (cons row col) squares))))))

(defun mpuz-parity-digit-at-cell (row col)
  (catch 'found
    (dotimes (digit 10)
      (when (mpuz-parity-digit-appears-p digit row col)
        (throw 'found digit)))
    -1))

(defun mpuz-parity-board-text ()
  (let (parts)
    (dolist (row '(2 4 6 8 10))
      (dolist (col '(1 3 5 7 9))
        (let ((digit (mpuz-parity-digit-at-cell row col)))
          (when (>= digit 0)
            (push (format "%d:%d=%d" row col digit) parts)))))
    (mapconcat #'identity (nreverse parts) ",")))

(defun mpuz-parity-screen-lines ()
  (let ((buf (mpuz-create-buffer)))
    (with-current-buffer buf
      (let ((buffer-read-only nil))
        (untabify (point-min) (point-max)))
      (split-string (buffer-string) "\n"))))

(defun mpuz-parity-emit-screen ()
  (let ((index 1))
    (dolist (line (mpuz-parity-screen-lines))
      (princ (format "screen|%d|%s\n" index line))
      (setq index (1+ index)))))

(defun mpuz-parity-emit-state (name)
  (princ (format "case|%s\n" name))
  (princ (format "state|in-progress|%s\n" (mpuz-parity-bool-text mpuz-in-progress)))
  (princ (format "state|errors|%d\n" mpuz-nb-errors))
  (princ (format "state|completed|%d\n" mpuz-nb-completed-games))
  (princ (format "state|cumulated|%d\n" mpuz-nb-cumulated-errors))
  (princ (format "state|found|%s\n" (mpuz-parity-flags-text mpuz-found-digits)))
  (princ (format "state|trivial|%s\n" (mpuz-parity-flags-text mpuz-trivial-digits)))
  (princ (format "state|average|%s\n" (mpuz-parity-average-text)))
  (princ (format "state|mapping|%s\n" (mpuz-parity-mapping-text)))
  (princ (format "state|board|%s\n" (mpuz-parity-board-text)))
  (mpuz-parity-emit-screen))

(defun mpuz-parity-letter-for-digit (digit)
  (+ ?A (aref mpuz-digit-to-letter digit)))

(defun mpuz-parity-try-proposal (letter-char digit-char)
  (let* ((letter (- (upcase letter-char) ?A))
         (digit (- digit-char ?0)))
    (cond
     ((or (< letter 0) (>= letter 10) (< digit 0) (>= digit 10))
      (cons "bad-input" -1))
     (t
      (let ((correct-digit (aref mpuz-letter-to-digit letter)))
        (cond
         ((mpuz-digit-solved-p correct-digit)
          (cons "already-solved" correct-digit))
         ((null (aref mpuz-board correct-digit))
          (cons "does-not-appear" correct-digit))
         ((mpuz-digit-solved-p digit)
          (cons "digit-already-placed" correct-digit))
         ((= digit correct-digit)
          (mpuz-try-proposal (upcase letter-char) digit-char)
          (cons "correct" correct-digit))
         (t
          (mpuz-try-proposal (upcase letter-char) digit-char)
          (cons "incorrect" correct-digit))))))))

(defun mpuz-parity-emit-try (name letter-char digit-char)
  (let ((result (mpuz-parity-try-proposal letter-char digit-char)))
    (princ (format "op|%s|%s|correct-digit=%d\n" name (car result) (cdr result))))
  (mpuz-parity-emit-state name))

(defun mpuz-parity-close-game-core ()
  (when mpuz-in-progress
    (setq mpuz-in-progress nil
          mpuz-nb-cumulated-errors (+ mpuz-nb-cumulated-errors mpuz-nb-errors)
          mpuz-nb-completed-games (1+ mpuz-nb-completed-games))))

(defun mpuz-parity-emit-check-all-solved (name)
  (princ (format "op|%s|check-all-solved=%s\n"
                 name (mpuz-parity-bool-text (mpuz-check-all-solved))))
  (mpuz-parity-emit-state name))

(defun mpuz-parity-mark-found (digits)
  (dolist (digit digits)
    (aset mpuz-found-digits digit t)))

(defun mpuz-parity-run-branch-parity ()
  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-emit-state "fixture-a-fresh")
  (mpuz-parity-emit-try "try-incorrect" (mpuz-parity-letter-for-digit 3) ?4)
  (mpuz-parity-emit-try "try-correct" (mpuz-parity-letter-for-digit 3) ?3)
  (mpuz-parity-emit-try "try-already-solved" (mpuz-parity-letter-for-digit 3) ?3)
  (mpuz-parity-emit-try "try-digit-already-placed" (mpuz-parity-letter-for-digit 5) ?3)

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-emit-try "try-does-not-appear" (mpuz-parity-letter-for-digit 9) ?9)
  (mpuz-parity-emit-try "try-bad-digit" (mpuz-parity-letter-for-digit 3) ?X))

(defun mpuz-parity-run-row-solve-parity ()
  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 2)
  (mpuz-parity-emit-state "solve-row-2")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 4)
  (mpuz-parity-emit-state "solve-row-4")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 4 7)
  (mpuz-parity-emit-state "solve-row-4-col-7")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 4 9)
  (mpuz-parity-emit-state "solve-row-4-col-9")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 6)
  (mpuz-parity-emit-state "solve-row-6")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 6 9)
  (mpuz-parity-emit-state "solve-row-6-col-9")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 8)
  (mpuz-parity-emit-state "solve-row-8")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 8 7)
  (mpuz-parity-emit-state "solve-row-8-col-7")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve 10)
  (mpuz-parity-emit-state "solve-row-10")

  (mpuz-parity-reset-fixture-a)
  (mpuz-solve)
  (mpuz-check-all-solved)
  (mpuz-parity-close-game-core)
  (mpuz-parity-emit-state "solve-full-close"))

(defun mpuz-parity-run-auto-solve-parity ()
  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(4 7))
  (mpuz-parity-emit-check-all-solved "autosolve-b1-b2")

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(1 2 3 4))
  (mpuz-parity-emit-check-all-solved "autosolve-d-to-e")

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(1 2 3 4 6 8))
  (mpuz-parity-emit-check-all-solved "autosolve-e-and-d-to-c")

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(0 2 3 5 6 8))
  (mpuz-parity-emit-check-all-solved "autosolve-a-c-to-b2")

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(1 2 3 4 5 8))
  (mpuz-parity-emit-check-all-solved "autosolve-a-d-to-b1")

  (mpuz-parity-reset-fixture-a)
  (mpuz-parity-mark-found '(0 2 5 6 7))
  (mpuz-parity-emit-check-all-solved "autosolve-b2-c-to-a")

  (mpuz-parity-reset-fixture-a)
  (setq mpuz-solve-when-trivial nil)
  (mpuz-parity-mark-found '(4 7))
  (mpuz-parity-emit-check-all-solved "autosolve-disabled-b1-b2"))

(defun mpuz-parity-run-fixture-parity ()
  (mpuz-parity-reset-fixture mpuz-parity-mapping-b 125 9 8)
  (mpuz-parity-emit-state "fixture-b-zeros")

  (mpuz-parity-reset-fixture mpuz-parity-mapping-c 987 6 5)
  (mpuz-parity-emit-state "fixture-c-repeated-digits"))

(defun mpuz-parity-run-random-parity (name draws allow-double)
  (setq mpuz-in-progress t
        mpuz-solve-when-trivial t
        mpuz-allow-double-multiplicator allow-double
        mpuz-nb-errors 0
        mpuz-nb-completed-games 0
        mpuz-nb-cumulated-errors 0
        mpuz-parity-active-draws draws
        mpuz-parity-active-draw-index 0)
  (fillarray mpuz-found-digits nil)
  (fillarray mpuz-trivial-digits nil)
  (cl-letf (((symbol-function 'random) #'mpuz-parity-random))
    (mpuz-random-puzzle))
  (princ (format "op|%s|draws-used=%d\n" name mpuz-parity-active-draw-index))
  (mpuz-parity-emit-state name))

(defun mpuz-parity-run-random-generation-parity ()
  (mpuz-parity-run-random-parity
   "random-draws-no-double-with-retry" mpuz-parity-draw-stream-a nil)
  (mpuz-parity-run-random-parity
   "random-draws-allow-double" mpuz-parity-draw-stream-b t))

(defun mpuz-parity-run ()
  (mpuz-parity-run-branch-parity)
  (mpuz-parity-run-row-solve-parity)
  (mpuz-parity-run-auto-solve-parity)
  (mpuz-parity-run-fixture-parity)
  (mpuz-parity-run-random-generation-parity))

(mpuz-parity-run)
