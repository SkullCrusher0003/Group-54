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
