class AddPlotReferenceToPlanningActivityProductionExtBatch < ActiveRecord::Migration[4.2]
  def change
    unless column_exists?(:activity_production_batches, :planning_scenario_activity_plot)
      add_reference :activity_production_batches, :planning_scenario_activity_plot, foreign_key: true
    end
  end
end
