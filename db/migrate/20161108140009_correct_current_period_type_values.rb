class CorrectCurrentPeriodTypeValues < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE preferences SET string_value = 'year' WHERE name = 'current_period_interval' AND string_value = 'years'"
    execute "UPDATE preferences SET string_value = 'month' WHERE name = 'current_period_interval' AND string_value = 'months'"
  end
end
