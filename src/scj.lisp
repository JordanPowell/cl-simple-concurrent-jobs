(in-package #:cl-simple-concurent-jobs)

(defmacro with-job-executor-lock ((worker) &body body)
  (let ((je (gensym)))
    `(let ((,je ,worker))
       (bt:with-recursive-lock-held ((je-lock ,je))
	 ,@body))))

(defclass JobExecutor ()
  ((num-threads :initarg :num-threads :reader num-threads)
   (chanl-tasks :accessor chanl-tasks)
   (results :accessor results :initform nil)
   (num-expected-results :accessor num-expected-results :initform 0)
   (num-results-got :accessor num-results-got :initform 0)
   (completion-condition :initform (bt:make-condition-variable)
			 :reader completion-condition)
   (should-run :initform t :accessor should-run)
   (je-lock :initform (bt:make-recursive-lock) :reader je-lock)
   (channel :initform (make-instance 'chanl:unbounded-channel)
	    :reader channel)))

(defgeneric has-all-results (JobExecutor))
(defgeneric append-result (JobExecutor result))
(defgeneric create-job-for-executor (JobExecutor))
(defgeneric add-job (JobExecutor callable))
(defgeneric join-results (JobExecutor))
(defgeneric stop (JobExecutor))

(defmethod has-all-results ((je JobExecutor))
  (with-job-executor-lock (je)
    (eql (num-expected-results je) (num-results-got je))))

(defmethod append-result ((je JobExecutor) result)
  (with-job-executor-lock (je)
    (incf (num-results-got je))
    (push result (results je))
    (when (has-all-results je)
      (bt:condition-notify (completion-condition je)))))

(defmethod create-job-for-executor ((je JobExecutor))
  (chanl:pexec ()
    (loop while (should-run je)
       do (let ((result nil))
	    ;; this is awful, but the way we block on jobs completing
	    ;; requires something like this. Any better ideas?
	    (unwind-protect (setf result (funcall (chanl:recv (channel je))))
	      (append-result je result))))))

(defmethod add-job ((je JobExecutor) callable)
  (with-job-executor-lock (je)
    (incf (num-expected-results je))
    (chanl:send (channel je) callable)
    (num-expected-results je)))

(defmethod join-results ((je JobExecutor))
  (with-job-executor-lock (je)
    (if (or (not (should-run je))
	    (has-all-results je))
	(results je)
	(progn
	  (bt:condition-wait (completion-condition je) (je-lock je))
	  (results je)))))

(defmethod stop ((je JobExecutor))
  (setf (should-run je) nil)
  (bt:condition-notify (completion-condition je)))

(defmethod initialize-instance :after ((je JobExecutor) &key)
  (setf (chanl-tasks je)
	(loop for i from 0 to (- (num-threads je) 1) collect
	     (create-job-for-executor je))))

(defun create-job-executor (&key (num-threads 8))
  (make-instance 'JobExecutor :num-threads num-threads))
