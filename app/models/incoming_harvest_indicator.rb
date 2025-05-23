# frozen_string_literal: true

# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2014 Brice Texier, David Joulin
# Copyright (C) 2015-2023 Ekylibre SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: economic_indicators
#
#  activity_id            :integer(4)
#  activity_size_unit     :string
#  activity_size_value    :decimal(, )
#  amount                 :decimal(, )
#  campaign_id            :integer(4)
#  economic_indicator     :text
#  output_variant_id      :integer(4)
#  output_variant_unit_id :integer(4)
#
class IncomingHarvestIndicator < ApplicationRecord
  belongs_to :campaign
  belongs_to :activity
  belongs_to :activity_production
  belongs_to :crop, class_name: 'Product'

  scope :of_campaign, ->(campaign) { where(campaign: campaign)}
  scope :of_activity, ->(activity) { where(activity: activity)}

  class << self
    def refresh
      Scenic.database.refresh_materialized_view(table_name, concurrently: false, cascade: false)
    end
  end

  def readonly?
    true
  end

  def activity_production_cost_per_area
    cost = activity_production.decorate.production_costs(campaign)
    cost[:cultivated_hectare_costs][:total]
  end

end
