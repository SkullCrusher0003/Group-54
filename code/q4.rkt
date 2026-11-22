#lang racket/base

;; (my-length lst): base case: lst is empty, so the length is 0; otherwise: the length is 1 (for the first element, atom or sublist, never looked into) plus the length of the rest, computed with a running count so the recursion is a tail call
(define (my-length lst)
  (let walk ((rest-items lst) (count 0))
    (cond
      ((null? rest-items) count)
      (else (walk (cdr rest-items) (+ count 1))))))

;; (my-map f lst): base case: lst is empty, so the result is the empty list; otherwise: cons (f applied to the first element) onto the result of my-map on the rest of the list, which keeps the order
(define (my-map f lst)
  (cond
    ((null? lst) '())
    (else (cons (f (car lst)) (my-map f (cdr lst))))))

;; (insert-if-short x lst n): base case: an atom (neither a pair nor the empty list) is returned unchanged, and an empty list is handled by the same rule as any list because my-map over it gives the empty list; otherwise: rebuild the list by my-map, replacing each sublist with insert-if-short on it and keeping atoms, then put x in front exactly when the length of the original lst is less than n
(define (insert-if-short x lst n)
  (let ((new-items
         (my-map (lambda (item)
                   (cond
                     ((or (pair? item) (null? item)) (insert-if-short x item n))
                     (else item)))
                 lst)))
    (cond
      ((< (my-length lst) n) (cons x new-items))
      (else new-items))))

;; (print-insert-result): base case: none, there is no recursion; otherwise: read x, then read lst, then read n (in that order, each bound by let*), compute (insert-if-short x lst n), display the result, and finish with newline so the last value is void
(define (print-insert-result)
  (let* ((x (read))
         (lst (read))
         (n (read)))
    (display (insert-if-short x lst n))
    (newline)))

;; (make-inserter x len-ok?): base case: none, it only returns a one-argument function (no recursion of its own); otherwise: the returned function calls the local helper (process tree) on its list
;; (process tree): base case: an atom (neither a pair nor the empty list) is returned unchanged; otherwise: rebuild the list with my-map, replacing each element by (process element), then put x in front exactly when (len-ok? (my-length tree)) holds for the original tree
(define (make-inserter x len-ok?)
  (letrec ((process
            (lambda (tree)
              (cond
                ((or (pair? tree) (null? tree))
                 (let ((new-items (my-map process tree)))
                   (cond
                     ((len-ok? (my-length tree)) (cons x new-items))
                     (else new-items))))
                (else tree)))))
    (lambda (lst) (process lst))))
