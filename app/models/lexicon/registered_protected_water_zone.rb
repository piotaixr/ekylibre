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
# == Table: registered_protected_water_zones
#
#  administrative_zone :string
#  creator_name        :string
#  id                  :string           not null
#  name                :string
#  shape               :geometry({:srid=>4326, :type=>"multi_polygon"}) not null
#  updated_on          :date
#
class RegisteredProtectedWaterZone < LexiconRecord
  include Lexiconable
  include Ekylibre::Record::HasShape

  has_geometry :shape

  def label
    if name.present?
      name
    elsif creator_name.present?
      creator_name
    end
  end

end
