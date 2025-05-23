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
# == Table: product_nature_variant_readings
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
#  point_value                  :geometry({:srid=>4326, :type=>"st_point"})
#  string_value                 :text
#  updated_at                   :datetime         not null
#  updater_id                   :integer(4)
#  variant_id                   :integer(4)       not null
#
require 'test_helper'

class ProductNatureVariantReadingTest < Ekylibre::Testing::ApplicationTestCase::WithFixtures
  test_model_actions
  # Add tests here...
end
