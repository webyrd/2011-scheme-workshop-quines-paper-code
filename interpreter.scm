(load "testcheck.scm")
(load "appendixC.scm")
(load "appendixD.scm")
(load "interp-helpers.scm")

(define eval-exp
  (lambda (exp env)
    (dmatch exp
      ((,rator ,rand)
       (let ((proc (eval-exp rator env))
             (arg (eval-exp rand env)))
         (dmatch proc
           ((closure ,x ,body ,env2)
            (eval-exp body `((,x . ,arg) . ,env2))))))      
      ((lambda (,x) ,body)
       (guard (symbol? x) (not-in-env 'lambda env))
       `(closure ,x ,body ,env))
      (,x (guard (symbol? x)) (lookup x env)))))

(define big-omega
  '((lambda (lambda) (lambda lambda))
    (lambda (lambda) (lambda lambda))))

; diverges!
; (eval-exp big-omega '())

(test-check "interp-1"
  (eval-exp
   '(((lambda (x)
        (lambda (y) x))
      (lambda (z) z))
     (lambda (a) a))
   '())
  '(closure z z ()))

(test-check "interp-2"
  (eval-exp
   '((lambda (x)
       (lambda (y) x))
     (lambda (z) z))
   '())
  '(closure y x ((x . (closure z z ())))))

(define fail (== #f #t))

(define lookupo
  (lambda (x env t)
    (conde
      ((== '() env) fail)
      ((fresh (y v rest)
         (== `((,y . ,v) . ,rest) env) (== y x)
         (== v t)))
      ((fresh (y v rest)
         (== `((,y . ,v) . ,rest) env) (=/= y x)
         (lookupo x rest t))))))

(test-check "interp-3"
  (run* (q) (lookupo 'y '((x . foo) (y . bar)) q))
  '(bar))

(test-check "interp-4"
  (run* (q) (lookupo 'w '((x . foo) (y . bar)) q))
  '())

(define lookupo
  (lambda (x env t)
    (fresh (y v rest)
      (== `((,y . ,v) . ,rest) env)
      (conde
        ((== y x) (== v t))
        ((=/= y x) (lookupo x rest t))))))

(test-check "interp-5"
  (run* (q) (lookupo 'y '((x . foo) (y . bar)) q))
  '(bar))

(test-check "interp-6"
  (run* (q) (lookupo 'w '((x . foo) (y . bar)) q))
  '())

(define eval-expo
  (lambda (exp env val)
    (conde
      ((fresh (rator rand x body env2 a)
         (== `(,rator ,rand) exp)
         (eval-expo rator env `(closure ,x ,body ,env2))
         (eval-expo rand env a)
         (eval-expo body `((,x . ,a) . ,env2) val)))
      ((fresh (x body)
         (== `(lambda (,x) ,body) exp)
         (symbolo x)
         (== `(closure ,x ,body ,env) val)
         (not-in-envo 'lambda env)))
      ((symbolo exp) (lookupo exp env val)))))

(test-check "interp-7"
  (run 5 (q)
    (fresh (e v)
      (eval-expo e '() v)
      (== `(,e -> ,v) q)))
  '((((lambda (_.0) _.1) -> (closure _.0 _.1 ())) (sym _.0))
    ((((lambda (_.0) _.0) (lambda (_.1) _.2))
      ->
      (closure _.1 _.2 ()))
     (sym _.0 _.1))
    ((((lambda (_.0) (lambda (_.1) _.2)) (lambda (_.3) _.4))
      ->
      (closure _.1 _.2 ((_.0 closure _.3 _.4 ()))))
     (=/= ((_.0 lambda)))
     (sym _.0 _.1 _.3))
    ((((lambda (_.0) (_.0 _.0)) (lambda (_.1) _.1))
      ->
      (closure _.1 _.1 ()))
     (sym _.0 _.1))
    ((((lambda (_.0) (_.0 _.0))
       (lambda (_.1) (lambda (_.2) _.3)))
      ->
      (closure _.2 _.3 ((_.1 closure _.1 (lambda (_.2) _.3) ()))))
     (=/= ((_.1 lambda)))
     (sym _.0 _.1 _.2))))

(test-check "interp-8"
  (run 5 (q)
    (eval-expo q '() '(closure y x ((x . (closure z z ()))))))
  '(((lambda (x) (lambda (y) x)) (lambda (z) z))
    ((lambda (x) (x (lambda (y) x))) (lambda (z) z))
    (((lambda (x) (lambda (y) x))
      ((lambda (_.0) _.0) (lambda (z) z)))
     (sym _.0))
    ((((lambda (_.0) _.0) (lambda (x) (lambda (y) x)))
      (lambda (z) z))
     (sym _.0))
    (((lambda (_.0) _.0)
      ((lambda (x) (lambda (y) x)) (lambda (z) z)))
     (sym _.0))))
