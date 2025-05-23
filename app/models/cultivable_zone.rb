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
# == Table: cultivable_zones
#
#  codes                  :jsonb
#  created_at             :datetime         not null
#  creator_id             :integer(4)
#  custom_fields          :jsonb
#  description            :text
#  farmer_id              :integer(4)
#  id                     :integer(4)       not null, primary key
#  lock_version           :integer(4)       default(0), not null
#  name                   :string           not null
#  owner_id               :integer(4)
#  production_system_name :string
#  provider               :jsonb
#  shape                  :geometry({:srid=>4326, :type=>"multi_polygon"}) not null
#  soil_nature            :string
#  updated_at             :datetime         not null
#  updater_id             :integer(4)
#  uuid                   :uuid
#  work_number            :string           not null
#

class CultivableZone < ApplicationRecord
  include Attachable
  include Customizable
  include Providable
  refers_to :production_system
  refers_to :soil_nature
  belongs_to :farmer, class_name: 'Entity'
  belongs_to :owner, class_name: 'Entity'
  has_many :activity_productions, foreign_key: :cultivable_zone_id
  has_many :activities, through: :activity_productions
  has_many :analyses, dependent: :nullify
  has_many :current_activity_productions, -> { current }, foreign_key: :cultivable_zone_id, class_name: 'ActivityProduction'
  has_many :current_supports, through: :current_activity_productions, source: :support
  has_many :supports, through: :activity_productions
  has_many :rides

  has_geometry :shape, type: :multi_polygon
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :description, length: { maximum: 500_000 }, allow_blank: true
  validates :name, :work_number, presence: true, length: { maximum: 500 }
  validates :shape, presence: true
  # ]VALIDATORS]
  validates :shape, shape: true
  validates :uuid, presence: true

  scope :of_current_activity_productions, -> { where(id: ActivityProduction.select(:cultivable_zone_id).current) }
  scope :of_campaign, ->(campaign) { where(id: ActivityProduction.select(:cultivable_zone_id).of_campaign(campaign)) }
  scope :of_production_system, ->(production_system) { where('production_system_name IS NULL OR production_system_name = ? OR production_system_name = ?', '', production_system) }

  protect on: :destroy do
    activity_productions.any?
  end

  before_validation do
    self.uuid ||= UUIDTools::UUID.random_create.to_s
    self.work_number ||= UUIDTools::UUID.parse(self.uuid).to_i.to_s(36)
  end

  alias net_surface_area shape_area

  def shape_svg
    shape.to_svg
  end

  def shape_to_geojson
    shape.to_geojson
  end

  # get the first object with variety 'plant', availables
  def current_cultivations(at = Time.zone.now)
    Plant.contained_by(current_supports, at)
  end

  # Returns last created islet number from cap statements
  def cap_number
    islets = CapIslet.shape_intersecting(shape).order(id: :desc)
    return islets.first.islet_number if islets.any?

    nil
  end

  # compute the number of unique activity on a cultivable zone on a year
  def computed_next_cultivable_zone_rank_number(campaign)
    if campaign.present?
      activity_productions.of_campaign(campaign).pluck(:activity_id).uniq.count
    else
      activity_productions.pluck(:activity_id).uniq.count
    end
  end

  def city_name
    islets = CapIslet.shape_intersecting(shape).order(id: :desc)
    return islets.first.city_name if islets.any?

    nil
  end

  # return cadastral_land_parcels intersecting cultivable_zone
  def cadastral_land_parcels
    cadastrals = RegisteredCadastralParcel.shape_intersecting(shape).order(section: :asc, work_number: :asc)
    return cadastrals if cadastrals.any?

    nil
  end

  # return protected_water_zones intersecting cultivable_zone
  def protected_water_zones
    water_zones = RegisteredProtectedWaterZone.shape_intersecting(shape)
    return water_zones if water_zones.any?

    nil
  end

  # return natural_zones intersecting cultivable_zone
  def natural_zones
    natural_zones = RegisteredNaturalZone.shape_intersecting(shape)
    return natural_zones if natural_zones.any?

    nil
  end

  # return edge intersecting cultivable_zone
  def edge_zones
    edge_zones = RegisteredAreaItem.of_nature(:edge).buffer_intersecting(0.7, shape)
    return edge_zones if edge_zones.any?

    nil
  end

  # return edge length bordering cultivable_zone in meter
  def edge_length
    edges = edge_zones
    if edges.present?
      total = 0.0
      edges.each do |edge|
        total += edge.geometry.to_rgeo.length
      end
      total.round(2).in_meter
    else
      nil
    end
  end

  # return theoritical soil depth intersecting cultivable_zone
  def theoritical_soil_depths
    zones = RegisteredSoilDepth.shape_intersecting(shape)
    return zones if zones.any?

    nil
  end

  # return theoritical water capacities intersecting cultivable_zone
  def theoritical_water_capacities
    zones = RegisteredSoilAvailableWaterCapacity.shape_intersecting(shape)
    return zones if zones.any?

    nil
  end

  after_commit do
    activity_productions.each(&:update_names)
    Ekylibre::Hook.publish(:cultivable_zone_change, cultivable_zone_id: id)
  end

  after_destroy do
    Ekylibre::Hook.publish(:cultivable_zone_destroy, cultivable_zone_id: id)
  end
end
