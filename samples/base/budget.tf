# FinOps: alert at 50 / 90 / 100 % of the monthly budget (disabled when billing_account is null or empty).
resource "google_billing_budget" "this" {
  count = var.billing_account == null ? 0 : (var.billing_account == "" ? 0 : 1)

  billing_account = var.billing_account
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
