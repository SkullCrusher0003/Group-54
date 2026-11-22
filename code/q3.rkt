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

;; (preorder-onto tree acc): base case: tree is '(): the answer is acc unchanged; otherwise: the answer is the node's value consed in front of the preorder list of the left subtree, which is built onto the preorder list of the right subtree onto acc, i.e. (cons value (preorder-onto left (preorder-onto right acc)))
(define (preorder-onto tree acc)
  (cond
    ((null? tree) acc)
    (else
     (cons (car tree)
           (preorder-onto (cadr tree)
                          (preorder-onto (caddr tree) acc))))))

;; (postorder-onto tree acc): base case: tree is '(): the answer is acc unchanged; otherwise: the answer is the postorder list of the left subtree built onto the postorder list of the right subtree built onto the node's value consed in front of acc, i.e. (postorder-onto left (postorder-onto right (cons value acc)))
(define (postorder-onto tree acc)
  (cond
    ((null? tree) acc)
    (else
     (postorder-onto (cadr tree)
                     (postorder-onto (caddr tree)
                                     (cons (car tree) acc))))))

;; (print-all-traversals tree): base case: none needed, the empty tree gives '() from all three helpers so "()" is displayed on each line; otherwise: display the inorder list, newline, the preorder list, newline, the postorder list, and end with newline, which also makes the result void
(define (print-all-traversals tree)
  (display (inorder-onto tree '()))
  (newline)
  (display (preorder-onto tree '()))
  (newline)
  (display (postorder-onto tree '()))
  (newline))
