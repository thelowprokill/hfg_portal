defmodule LoanRepayment.Loans do
  @topic "loan_repayment:loans"
  @schema LoanRepayment.Loans.Loan
  @updated [:loan, :updated]
  @created [:loan, :created]
  @deleted [:loan, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
end
