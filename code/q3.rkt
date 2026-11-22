#lang racket/base

;; (inorder-onto tree acc): base case: tree is '(): the answer is acc unchanged; otherwise: the answer is the inorder list of the left subtree followed by the node's value consed in front of the inorder list of the right subtree onto acc, i.e. (inorder-onto left (cons value (inorder-onto right acc)))
(define (inorder-onto tree acc)
  (cond
    ((null? tree) acc)
    (else
     (inorder-onto (cadr tree)
                   (cons (car tree)
                         (inorder-onto (caddr tree) acc))))))

;; (print-inorder tree): base case: none needed, the empty tree is handled by inorder-onto, which gives '() so "()" is displayed; otherwise: display the inorder list of the tree (inorder-onto tree '()), then end the line with newline, which also makes the result void
(define (print-inorder tree)
  (display (inorder-onto tree '()))
  (newline))
