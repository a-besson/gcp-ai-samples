# FinOps: alert at 50 / 90 / 100 % of the monthly budget.
# Billing account resolution: var.billing_account if set, else the account linked to the project
# (data source, only readable once the Cloud Billing API is enabled and visible to the caller),
# else no budget.
locals {
  billing_account = try(coalesce(var.billing_account, data.google_project.this.billing_account), "")
}

resource "google_billing_budget" "this" {
  count = local.billing_account == "" ? 0 : 1

  billing_account = local.billing_account
  display_name    = "budget-${local.prefix}"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  depends_on = [google_project_service.apis]
}
