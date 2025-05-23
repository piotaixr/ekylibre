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
# == Table: intervention_parameter_readings
#
#  absolute_measure_value_unit  :string
#  absolute_measure_value_value :decimal(19, 4)
#  boolean_value                :boolean          default(FALSE), not null
#  choice_value                 :string
#  created_at                   :datetime         not null
#  creator_id                   :integer(4)
#  decimal_value                :decimal(19, 4)
#  geometry_value               :geometry({:srid=>4326, :type=>"geometry"})
#  id                           :integer(4)       not null, primary key
#  indicator_datatype           :string           not null
#  indicator_name               :string           not null
#  integer_value                :integer(4)
#  lock_version                 :integer(4)       default(0), not null
#  measure_value_unit           :string
#  measure_value_value          :decimal(19, 4)
#  multi_polygon_value          :geometry({:srid=>4326, :type=>"multi_polygon"})
#  parameter_id                 :integer(4)       not null
#  point_value                  :geometry({:srid=>4326, :type=>"st_point"})
#  string_value                 :text
#  updated_at                   :datetime         not null
#  updater_id                   :integer(4)
#

class InterventionParameterReading < ApplicationRecord
  include ReadingStorable
  belongs_to :intervention_parameter, class_name: 'InterventionProductParameter', foreign_key: :parameter_id, inverse_of: :readings
  has_one :intervention, through: :intervention_parameter
  has_one :product, through: :intervention_parameter
  has_one :product_reading, as: :originator
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :absolute_measure_value_unit, :choice_value, length: { maximum: 500 }, allow_blank: true
  validates :absolute_measure_value_value, :decimal_value, :measure_value_value, numericality: { greater_than: -1_000_000_000_000_000, less_than: 1_000_000_000_000_000 }, allow_blank: true
  validates :boolean_value, inclusion: { in: [true, false] }
  validates :indicator_datatype, :indicator_name, :intervention_parameter, presence: true
  validates :integer_value, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }, allow_blank: true
  validates :string_value, length: { maximum: 500_000 }, allow_blank: true
  # ]VALIDATORS]
  validates :indicator_name, uniqueness: { scope: :parameter_id }

  delegate :started_at, :stopped_at, to: :intervention

  validate do
    # If intervention_parameter is an output, product is not yet created (as it is created in interventionOutput after_save), so we check the variant indicators
    if intervention_parameter.is_a?(InterventionOutput)
      if intervention_parameter.variant && indicator && intervention_parameter.variant.indicators.exclude?(indicator)
        errors.add(:indicator_name, :invalid)
      end
    elsif product && indicator
      unless product.indicators.include?(indicator)
        errors.add(:indicator_name, :invalid)
      end
    end
  end

  after_save do
    if product
      case indicator_name
      when 'hour_counter'
        save_hour_counter
      when 'cut_vine'
        save_cut_vine
      else
        create_product_reading
      end
    end
  end

  def create_product_reading
    product_reading ||= product.readings.new(indicator_name: indicator_name)
    product_reading.originator = self

    product_reading.value = value
    product_reading.read_at = product.born_at || intervention.started_at || Time.now
    product_reading.save!
  end

  private

    def save_cut_vine
      product_reading ||= product.readings.find_by(indicator_name: indicator_name, originator: self)
      product_reading ||= product.readings.new(indicator_name: indicator_name)
      product_reading.originator = self
      product_reading.value = value
      product_reading.read_at = intervention.stopped_at
      product_reading.save!
    end

    def save_hour_counter
      self.product_reading ||= product.readings.find_by(indicator_name: indicator_name)

      return if self.product_reading.present? && self.product_reading.value > 0.in(:hour) && value.zero?

      return if self.product_reading.present? &&
                self.product_reading.read_at.present? &&
                self.product_reading.read_at > intervention.stopped_at

      if self.product_reading.nil?
        self.product_reading = product.readings.create!(
          indicator: indicator,
          measure_value_value: value,
          measure_value_unit: measure_value_unit,
          read_at: intervention.stopped_at
        )

        return
      end

      self.product_reading.read_at = intervention.stopped_at
      self.product_reading.value = value
      self.product_reading.save!
    end
end
