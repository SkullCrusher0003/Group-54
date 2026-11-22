#lang racket/base

;; (inorder-onto tree acc): base case: tree is '(): the answer is acc unchanged; otherwise: the answer is the inorder list of the left subtree followed by the node's value consed in front of the inorder list of the right subtree onto acc, i.e. (inorder-onto left (cons value (inorder-onto right acc)))
(define (inorder-onto tree acc)
  (cond
    ((null? tree) acc)
    (else
     (inorder-onto (cadr tree)
                   (cons (car tree)
                         (inorder-onto (caddr tree) acc))))))
