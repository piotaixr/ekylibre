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
# == Table: activity_productions
#
#  activity_id            :integer(4)       not null
#  batch_planting         :boolean
#  campaign_id            :integer(4)
#  created_at             :datetime         not null
#  creator_id             :integer(4)
#  cultivable_zone_id     :integer(4)
#  custom_fields          :jsonb
#  custom_name            :string
#  headland_shape         :geometry({:srid=>4326, :type=>"geometry"})
#  id                     :integer(4)       not null, primary key
#  irrigated              :boolean          default(FALSE), not null
#  lock_version           :integer(4)       default(0), not null
#  nitrate_fixing         :boolean          default(FALSE), not null
#  number_of_batch        :integer(4)
#  predicated_sowing_date :date
#  provider               :jsonb            default("{}")
#  rank_number            :integer(4)       not null
#  reference_name         :string
#  season_id              :integer(4)
#  size_indicator_name    :string           not null
#  size_unit_name         :string
#  size_value             :decimal(19, 4)   not null
#  sowing_interval        :integer(4)
#  started_on             :date
#  starting_year          :integer(4)
#  state                  :string
#  stopped_on             :date
#  support_id             :integer(4)       not null
#  support_nature         :string
#  support_shape          :geometry({:srid=>4326, :type=>"multi_polygon"})
#  tactic_id              :integer(4)
#  technical_itinerary_id :integer(4)
#  updated_at             :datetime         not null
#  updater_id             :integer(4)
#  usage                  :string           not null
#

class ActivityProduction < ApplicationRecord
  include Attachable
  include Customizable
  include Providable

  refers_to :support_nature, class_name: 'ProductionSupportNature'
  refers_to :usage, class_name: 'ProductionUsage'
  refers_to :size_indicator, class_name: 'Indicator'
  refers_to :size_unit, class_name: 'Unit'
  belongs_to :activity, inverse_of: :productions
  belongs_to :campaign
  belongs_to :cultivable_zone
  belongs_to :support, class_name: 'Product' # , inverse_of: :supports
  belongs_to :tactic, class_name: 'ActivityTactic', inverse_of: :productions
  belongs_to :season, class_name: 'ActivitySeason', inverse_of: :productions
  has_many :products
  has_many :budgets, through: :activity
  has_many :manure_management_plan_zones, class_name: 'ManureManagementPlanZone',
                                          inverse_of: :activity_production
  has_one :selected_manure_management_plan_zone, -> { selecteds },
          class_name: 'ManureManagementPlanZone', inverse_of: :activity_production
  has_one :cap_land_parcel, class_name: 'CapLandParcel', inverse_of: :activity_production, foreign_key: :support_id

  has_and_belongs_to_many :interventions
  has_and_belongs_to_many :campaigns
  belongs_to :production_nature, primary_key: :reference_name, class_name: 'MasterProduction', foreign_key: :reference_name

  # planning
  belongs_to :technical_itinerary, class_name: 'TechnicalItinerary'
  has_one :batch, class_name: 'ActivityProductionBatch', dependent: :destroy, inverse_of: :activity_production
  has_many :daily_charges, class_name: 'DailyCharge', dependent: :destroy, foreign_key: :activity_production_id
  has_many :intervention_proposals, class_name: 'InterventionProposal', dependent: :destroy, foreign_key: :activity_production_id

  accepts_nested_attributes_for :batch, allow_destroy: true

  has_geometry :support_shape, :headland_shape, type: :multi_polygon

  composed_of :size, class_name: 'Measure', mapping: [%w[size_value to_d], %w[size_unit_name unit]]

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :batch_planting, inclusion: { in: [true, false] }, allow_blank: true
  validates :custom_name, :reference_name, :state, length: { maximum: 500 }, allow_blank: true
  validates :irrigated, :nitrate_fixing, inclusion: { in: [true, false] }
  validates :number_of_batch, :sowing_interval, :starting_year, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }, allow_blank: true
  validates :predicated_sowing_date, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 100.years }, type: :date }, allow_blank: true
  validates :rank_number, presence: true, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }
  validates :activity, :size_indicator_name, :support, :usage, presence: true
  validates :size_value, presence: true, numericality: { greater_than: -1_000_000_000_000_000, less_than: 1_000_000_000_000_000 }
  validates :started_on, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.today + 100.years }, type: :date }, allow_blank: true
  validates :stopped_on, timeliness: { on_or_after: ->(activity_production) { activity_production.started_on || Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.today + 100.years }, type: :date }, allow_blank: true
  # ]VALIDATORS]
  validates :rank_number, uniqueness: { scope: :activity_id }
  validates :started_on, :stopped_on, presence: true
  # validates_presence_of :cultivable_zone, :support_nature, if: :plant_farming?
  validates :support_nature, presence: { if: -> { plant_farming? || vine_farming? } }
  validates :campaign, presence: { if: :annual? }
  validates :starting_year, presence: { if: :perennial? }, allow_blank: true, numericality: { greater_than_or_equal_to: ->(activity_production) { activity_production.started_on.year }, less_than_or_equal_to: ->(activity_production) { activity_production.stopped_on.year } }
  validates :support, presence: true
  validates_associated :support
  validates :batch_planting, inclusion: { in: [true, false] }, allow_blank: true
  validates :number_of_batch, :sowing_interval, numericality: { only_integer: true, greater_than: -2_147_483_649, less_than: 2_147_483_648 }, allow_blank: true
  validates :predicated_sowing_date, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years }, type: :date }, allow_blank: true
  validate :sowing_date_between_period_of_activity_production
  validate :stopped_on_after_last_intervention
  validate :support_shape_presence_if_vegetal_farming

  # validates_numericality_of :size_value, greater_than: 0
  # validates_presence_of :size_unit, if: :size_value?

  delegate :name, :work_number, to: :support, prefix: true
  # delegate :shape, :shape_to_ewkt, :shape_svg, :net_surface_area, :shape_area, to: :support
  delegate :name, :size_indicator_name, :size_unit_name, to: :activity, prefix: true
  delegate :animal_farming?, :plant_farming?, :tool_maintaining?, :vine_farming?, :use_seasons?, :use_tactics?,
           :with_cultivation, :cultivation_variety, :with_supports, :support_variety,
           :color, :annual?, :perennial?, :production_started_on_year,
           :production_stopped_on_year, :life_duration, :production_started_on, :production_stopped_on, to: :activity, allow_nil: true

  scope :of_campaign, lambda { |campaign|
    where(id: HABTM_Campaigns.select(:activity_production_id).where(campaign: campaign))
  }

  scope :with_cultivation_variety, lambda { |variety|
    where(activity: Activity.with_cultivation_variety(variety))
  }
  scope :of_cultivation_variety, lambda { |variety|
    where(activity: Activity.of_cultivation_variety(variety))
  }
  scope :of_cultivation_varieties, lambda { |*varieties|
    where(activity: Activity.of_cultivation_varieties(*varieties))
  }
  scope :of_current_campaigns, -> {
    of_campaign(Campaign.current.last)
  }

  scope :of_activity, ->(activity) { where(activity: activity) }
  scope :of_cultivable_zone, ->(cultivable_zone) { where(cultivable_zone: cultivable_zone) }
  scope :of_activities, lambda { |*activities|
    where(activity_id: activities.flatten.map(&:id))
  }
  scope :of_activity_families, lambda { |*families|
    where(activity: Activity.of_families(*families))
  }

  scope :of_crumbs, lambda { |*crumbs|
    options = crumbs.extract_options!
    options[:campaigns] ||= Campaign.current

    of_campaign(options[:campaigns].first).distinct
                                          .joins(:support)
                                          .joins('INNER JOIN crumbs ON ST_Contains(ST_CollectionExtract(activity_productions.support_shape, 3), crumbs.geolocation)')
                                          .where(crumbs.any? ? ['crumbs.id IN (?)', crumbs.flatten.map(&:id)] : 'crumbs.id IS NOT NULL')
  }

  scope :at, ->(at) { where(':now BETWEEN COALESCE(started_on, :now) AND COALESCE(stopped_on, :now)', now: at.to_date) }
  scope :start_before, ->(at) { where('started_on < ?', at.to_date) }
  scope :stop_after, ->(at) { where('stopped_on > ?', at.to_date) }
  scope :current, -> { at(Time.zone.now) }

  scope :with_technical_itinerary, -> { where.not(technical_itinerary: nil)}

  state_machine :state, initial: :opened do
    state :opened
    state :aborted
    state :closed

    event :abort do
      transition opened: :aborted
    end

    event :close do
      transition opened: :closed
    end

    event :reopen do
      transition closed: :opened
      transition aborted: :opened
    end
  end

  before_validation do
    self.state ||= :opened
    self.batch_planting ||= false
    self.started_on ||= Date.today
    self.usage ||= Onoma::ProductionUsage.first
    self.support_nature ||= :cultivation
    self.uuid ||= UUIDTools::UUID.random_create.to_s
    if activity
      self.stopped_on ||= self.started_on + 1.year - 1.day if annual?
      self.stopped_on ||= self.started_on + life_duration.to_i.year if perennial?
      self.size_indicator_name ||= activity_size_indicator_name if activity_size_indicator_name
      self.size_unit_name = activity_size_unit_name
      self.rank_number ||= activity.productions_next_rank_number
      self.cultivable_zone_rank_number ||= cultivable_zone.computed_next_cultivable_zone_rank_number(campaign) if cultivable_zone
      self.name = NamingFormats::LandParcels::BuildNamingService.new(activity_production: self).perform
      if valid_period_for_support?
        if plant_farming? || vine_farming?
          initialize_land_parcel_support!
        elsif animal_farming?
          initialize_animal_group_support!
        elsif tool_maintaining?
          initialize_equipment_fleet_support!
        end
      end
    end
    # planning
    destroy_batch
    true
  end

  after_save do
    support.update(activity_production: self) if support
  end

  after_commit do
    if activity.productions.where(rank_number: rank_number).count > 1
      update_column(:rank_number, activity.productions.maximum(:rank_number) + 1)
    end
    Ekylibre::Hook.publish(:activity_production_change, activity_production_id: id)
    # planning
    TechnicalItineraries::DailyChargesCreationInteractor
      .call({ activity_production: self })
  end

  after_destroy do
    Ekylibre::Hook.publish(:activity_production_destroy, activity_production_id: id)
    items = activity.budgets.of_campaign(campaign).first&.items
    items.each(&:save!) if items.present?
  end

  protect(on: :destroy) do
    if support
      interventions.any? || products.where.not(id: support.id).any?
    end
  end

  def self.retrieve_varieties_ancestors(*varieties)
    varieties.map do |variety|
      ancestors = [variety]
      nomen_variety = Onoma::Variety.find(variety)
      loop do
        nomen_variety = nomen_variety.parent
        ancestors << nomen_variety.name
        break if nomen_variety.name == 'plant'
      end
      ancestors
    end.flatten.uniq
  end

  # compile unique work_number for support
  # a : P_ for Parcel
  # b : First letter of activity cultivation variety (v for vitis, t for triticum)
  # c : production rank number
  # d : cultivable zone number (work number or cap number or id )
  # e : harvest year
  def computed_work_number
    work_number = 'P'.dup
    work_number << '_' << activity.cultivation_variety[0].upcase
    work_number << rank_number.to_s
    work_number << '_' << cultivable_zone.work_number || cultivable_zone.cap_number || cultivable_zone.id.to_s
    work_number << '_' + campaign.harvest_year.to_s if campaign
    work_number
  end

  # return if production is chemical, physical, both or none for weeding intervention
  def weeding_nature
    chemical_interventions = interventions.of_action(:herbicide).with_input_presence
    physical_interventions = interventions.of_action(:weeding).without_input_presence
    herbicide_pfi = PfiCampaignsActivitiesIntervention.of_activity_production(self).of_segment("S3")
    if (chemical_interventions.any? || herbicide_pfi.any?) && physical_interventions.any?
      :chemical_and_physical_weeding.tl
    elsif chemical_interventions.any? || herbicide_pfi.any?
      :chemical_weeding.tl
    elsif physical_interventions.any?
      :physical_weeding.tl
    else
      :no_weeding.tl
    end
  end

  def interventions_of_nature(nature)
    interventions
      .where(nature: nature)
  end

  def update_names
    if support && name
      support.update_column(:name, name) if support.name != name
    end
  end

  def valid_period_for_support?
    if self.started_on
      return false if self.started_on < Time.new(1, 1, 1).in_time_zone
    end
    if self.stopped_on
      return false if self.stopped_on >= Time.zone.now + 100.years
    end
    if self.started_on && self.stopped_on
      return false if self.started_on > self.stopped_on
    end
    true
  end

  def initialize_land_parcel_support!
    self.support_shape ||= cultivable_zone.shape if cultivable_zone
    unless support
      if self.support_shape
        land_parcels = LandParcel.shape_matching(self.support_shape)
                                 .where.not(id: ActivityProduction.select(:support_id))
                                 .order(:id)
        self.support = land_parcels.first if land_parcels.any?
      end
      self.support ||= LandParcel.new
    end
    support.name = name
    support.initial_shape = self.support_shape

    if self.activity && self.cultivable_zone
      support.work_number = computed_work_number
    end

    if support.initial_movement
      support.initial_movement.delta = support_shape_area.to_d(size_unit_name)
      support.initial_movement.started_at = started_on
      support.initial_movement.product = support
      support.initial_movement.save!
    end

    support.initial_population = support_shape_area.to_d(size_unit_name)
    support.initial_born_at = started_on
    support.initial_dead_at = stopped_on
    support.born_at = started_on
    support.dead_at = stopped_on
    support.variant ||= ProductNatureVariant.import_from_nomenclature(:land_parcel)
    support.save!
    reading = support.first_reading(:shape)
    if reading
      reading.value = self.support_shape
      reading.read_at = support.born_at
      reading.save!
    end
    self.size = support_shape_area.in(size_unit_name)
  end

  def initialize_animal_group_support!
    unless support
      self.support = AnimalGroup.new
      support.name = name
    end
    # FIXME: Need to find better category and population_counting...
    unless support.variant
      nature = ProductNature.find_or_create_by!(
        variety: :animal_group,
        derivative_of: :animal,
        name: AnimalGroup.model_name.human,
        category: ProductNatureCategory.import_from_nomenclature(:cattle_herd),
        population_counting: :unitary
      )
      variant = ProductNatureVariant.find_or_initialize_by(
        nature: nature,
        variety: :animal_group,
        derivative_of: :animal
      )
      variant.name ||= nature.name
      variant.unit_name ||= :unit.tl
      variant.save! if variant.new_record?
      support.variant = variant
    end
    if activity.cultivation_variety
      support.derivative_of ||= activity.cultivation_variety
    end
    support.save!
    if size_value.nil?
      errors.add(:size_value, :empty)
    else
      self.size = size_value.in(size_unit_name)
    end
  end

  def initialize_equipment_fleet_support!
    self.support = EquipmentFleet.new unless support
    support.name = name
    # FIXME: Need to find better category and population_counting...
    unless support.variant
      nature = ProductNature.find_or_create_by!(
        variety: :equipment_fleet,
        derivative_of: :equipment,
        name: EquipmentFleet.model_name.human,
        category: ProductNatureCategory.import_from_nomenclature(:equipment_fleet),
        population_counting: :unitary
      )
      variant = ProductNatureVariant.find_or_initialize_by(
        nature: nature,
        variety: :equipment_fleet,
        derivative_of: :equipment
      )
      variant.name ||= nature.name
      variant.unit_name ||= :unit.tl
      variant.save! if variant.new_record?
      support.variant = variant
    end
    if activity.cultivation_variety
      support.derivative_of ||= activity.cultivation_variety
    end
    support.save!
    if size_value.nil?
      errors.add(:size_value, :empty)
    else
      self.size = size_value.in(size_unit_name)
    end
  end

  def active?
    activity.family.to_s != 'fallow_land'
  end

  def season?
    !season_id.nil?
  end

  def interventions_by_weeks
    interventions_by_week = {}
    interventions.each do |intervention|
      week_number = intervention.started_at.to_date.cweek
      interventions_by_week[week_number] ||= []
      interventions_by_week[week_number] << intervention
    end
    interventions_by_week
  end

  def started_on_for(campaign)
    return started_on if annual?

    begin
      Date.civil(campaign.harvest_year + production_started_on_year, production_started_on.month, production_started_on.day)
    rescue
      Date.civil(campaign.harvest_year, 1, 1)
    end
  end

  def stopped_on_for(campaign)
    return stopped_on if annual?

    begin
      Date.civil(campaign.harvest_year + production_stopped_on_year, production_stopped_on.month, production_stopped_on.day)
    rescue
      Date.civil(campaign.harvest_year, 12, 31)
    end
  end

  # Used for find current campaign for given production
  def current_campaign
    Campaign.at(Time.zone.now).first
  end

  # planning
  def interventions_and_proposals_by_weeks
    interventions_by_week = {}
    interventions.each do |intervention|
      week_number = intervention.started_at.to_date.cweek
      interventions_by_week[week_number] ||= []
      interventions_by_week[week_number] << intervention
    end
    last_date = interventions.where.not(nature: :request).pluck(:started_at).max
    intervention_proposals
    .after_date(last_date&.to_date)
    .without_numbers(interventions.pluck(:number))
    .each do |intervention_proposal|
      week_number = intervention_proposal.estimated_date.cweek
      interventions_by_week[week_number] ||= []
      interventions_by_week[week_number] << intervention_proposal
    end

    interventions_by_week
  end

  def planning_working_zone_area
    self.decorate.human_working_zone_area
  end

  def destroy_batch
    return if batch_planting || batch.nil?

    if batch.irregular_batches.any?
      intervention_proposals = InterventionProposal
                                 .where(irregular_batch: batch.irregular_batches)

      intervention_proposals.each do |intervention_proposal|
        intervention_proposal.update_column(:activity_production_irregular_batch_id, nil)
      end
    end

    batch.destroy
  end

  # planning

  def cost(role = :input)
    costs = interventions.collect do |intervention|
      intervention.cost(role)
    end
    costs.compact.sum
  end

  # Returns the spreaded quantity of one chemicals components (N, P, K) per area unit
  # Get all intervention of category 'fertilizing' and sum all indicator unity spreaded
  #  - indicator could be (:potassium_concentration, :nitrogen_concentration, :phosphorus_concentration)
  #  - area_unit could be (:hectare, :square_meter)
  #  - from and to used to select intervention
  def soil_enrichment_indicator_content_per_area(indicator_name, from = nil, to = nil, area_unit_name = :hectare)
    balance = []
    procedure_category = :fertilizing
    interventions = if from && to
                      self.interventions.real.of_category(procedure_category).between(from, to)
                    else
                      self.interventions.real.of_category(procedure_category)
                    end
    interventions.each do |intervention|
      intervention.inputs.each do |input|
        # m = net_mass of the input at intervention time
        # n = indicator (in %) of the input at intervention time
        m = (input.actor ? input.actor.net_mass(input).to_d(:kilogram) : 0.0)
        # TODO: for method phosphorus_concentration(input)
        n = (input.actor ? input.actor.send(indicator_name).to_d(:unity) : 0.0)
        balance << m * n
      end
    end
    # if net_surface_area, make the division
    area = net_surface_area.to_d(area_unit_name)
    indicator_unity_per_hectare = balance.compact.sum / area if area.nonzero?
    indicator_unity_per_hectare
  end

  # TODO: for nitrogen balance but will be refactorize for any chemical components
  def nitrogen_balance
    # B = O - I
    balance = 0.0
    nitrogen_mass = []
    nitrogen_unity_per_hectare = nil
    if selected_manure_management_plan_zone
      # get the output O aka nitrogen_input from opened_at (in kg N / Ha )
      o = selected_manure_management_plan_zone.nitrogen_input || 0.0
      # get the nitrogen input I from opened_at to now (in kg N / Ha )
      opened_at = selected_manure_management_plan_zone.opened_at
      i = soil_enrichment_indicator_content_per_area(:nitrogen_concentration, opened_at, Time.zone.now)
      balance = o - i if i && o
    else
      balance = soil_enrichment_indicator_content_per_area(:nitrogen_concentration)
    end
    balance
  end

  def potassium_balance
    soil_enrichment_indicator_content_per_area(:potassium_concentration)
  end

  def phosphorus_balance
    soil_enrichment_indicator_content_per_area(:phosphorus_concentration)
  end

  def provisional_nitrogen_input
    0
  end

  def tool_cost(surface_unit_name = :hectare)
    surface_area = net_surface_area
    if surface_area.to_s.to_f > 0.0
      return cost(:tool) / surface_area.to_d(surface_unit_name).to_s.to_f
    end

    0.0
  end

  def input_cost(surface_unit_name = :hectare)
    surface_area = net_surface_area
    if surface_area.to_s.to_f > 0.0
      return cost(:input) / surface_area.to_d(surface_unit_name).to_s.to_f
    end

    0.0
  end

  def time_cost(surface_unit_name = :hectare)
    surface_area = net_surface_area
    if surface_area.to_s.to_f > 0.0
      return cost(:doer) / surface_area.to_d(surface_unit_name).to_s.to_f
    end

    0.0
  end

  # Returns all plants concerning by this activity production
  # TODO: No plant here, a more generic method should be largely preferable
  def inside_plants
    inside_products(Plant)
  end

  def inside_products(products = Product)
    products = if campaign
                 products.of_campaign(campaign)
               else
                 products.where(born_at: started_on..(stopped_on || Time.zone.now.to_date))
               end
    products.shape_within(support_shape)
  end

  # Returns the started_at attribute of the intervention of nature sowing if
  # exist and if it's a vegetal activity
  def implanted_at
    intervention = interventions.real.of_category(:planting).first
    return intervention.started_at if intervention

    nil
  end

  # Returns the started_at attribute of the intervention of nature harvesting
  # if exist and if it's a vegetal activity
  def harvested_at
    intervention = interventions.real.of_category(:harvesting).first
    return intervention.started_at if intervention

    nil
  end

  # Generic method to get harvest yield
  def harvest_yield(harvest_variety, options = {})
    size_indicator_name = options[:size_indicator_name] || :net_mass
    ind = Onoma::Indicator.find(size_indicator_name)
    raise "Invalid indicator: #{size_indicator_name}" unless ind

    size_unit_name = options[:size_unit_name] || ind.unit
    unless Onoma::Unit.find(size_unit_name)
      raise "Invalid indicator unit: #{size_unit_name.inspect}"
    end

    surface_unit_name = options[:surface_unit_name] || :hectare
    procedure_category = options[:procedure_category] || :harvesting
    surface = net_surface_area
    unless surface && surface.to_d > 0
      Rails.logger.warn 'No surface area. Cannot compute harvest yield'
      return nil
    end
    harvest_yield_unit_name = "#{size_unit_name}_per_#{surface_unit_name}".to_sym
    unless Onoma::Unit.find(harvest_yield_unit_name)
      raise "Harvest yield unit doesn't exist: #{harvest_yield_unit_name.inspect}"
    end

    total_quantity = 0.0.in(size_unit_name)

    target_distribution_plants = Plant.where(activity_production: self)
    # get harvest_interventions firstly by distributions and secondly by inside_plants method
    # harvest_interventions = Intervention.real.of_category(procedure_category).with_targets(target_distribution_plants) if target_distribution_plants.any?
    # harvest_interventions ||= Intervention.real.of_category(procedure_category).with_targets(inside_plants)
    harvest_interventions ||= interventions.real.of_category(procedure_category)

    coef_area = []
    global_coef_harvest_yield = []

    if harvest_interventions.any?
      harvest_interventions.includes(:targets).find_each do |harvest|
        harvest_working_area = harvest.working_zone_area(unit: surface_unit_name)
        harvest.outputs.each do |cast|
          actor = cast.product
          next unless actor && actor.variety

          variety = Onoma::Variety.find(actor.variety)
          if variety && variety <= harvest_variety
            quantity = cast.quantity_population.in(actor.variant.send(size_indicator_name).unit)
            total_quantity += quantity.convert(size_unit_name) if quantity
          end
        end

        h = harvest_working_area.to_f
        if h && h > 0.0
          global_coef_harvest_yield << (h * (total_quantity.to_f / h))
          coef_area << h
        end
      end
    end

    total_weighted_average_harvest_yield = global_coef_harvest_yield.compact.sum / coef_area.compact.sum if coef_area.compact.sum.to_d != 0.0
    # puts "total_weighted_average_harvest_yield : #{total_weighted_average_harvest_yield}".inspect.red
    m = Measure.new(total_weighted_average_harvest_yield.to_f, harvest_yield_unit_name)
    # puts "m : #{m}".inspect.red
    m.round(2)
  end

  # Returns the yield of grain in mass per surface unit
  def grains_yield(mass_unit_name = :quintal, surface_unit_name = :hectare)
    harvest_yield(:grain, procedure_category: :harvesting,
                          size_indicator_name: :net_mass,
                          size_unit_name: mass_unit_name,
                          surface_unit_name: surface_unit_name)
  end

  # Returns the yield of grain in mass per surface unit
  def fodder_yield(mass_unit_name = :ton, surface_unit_name = :hectare)
    harvest_yield(:grass, procedure_category: :harvesting,
                          size_indicator_name: :net_mass,
                          size_unit_name: mass_unit_name,
                          surface_unit_name: surface_unit_name)
  end

  # Returns the yield of grain in mass per surface unit
  def vegetable_yield(mass_unit_name = :ton, surface_unit_name = :hectare)
    harvest_yield(:grain, procedure_category: :harvesting,
                          size_indicator_name: :net_mass,
                          size_unit_name: mass_unit_name,
                          surface_unit_name: surface_unit_name)
  end

  # Returns the yield of grape in volume per surface unit
  def fruit_yield(volume_unit_name = :ton, surface_unit_name = :hectare)
    harvest_yield(:grape, procedure_category: :harvesting,
                          size_indicator_name: :net_volume,
                          size_unit_name: volume_unit_name,
                          surface_unit_name: surface_unit_name)
  end
  alias vine_yield fruit_yield

  # TODO: Which yield is computed? usage is not very good to determine yields
  #   because many yields can be computed...
  def estimate_yield(campaign, options = {})
    variety = options.delete(:variety)
    # compute variety for estimate yield
    if usage == 'grain' || usage == 'seed'
      variety ||= 'grain'
    elsif usage == 'fodder' || usage == 'fiber'
      variety ||= 'grass'
    end
    # get current campaign
    budget = activity.budget_of(campaign)
    return nil unless budget

    budget.estimate_yield(with_unit: true)
  end

  def current_cultivation
    # get the first object with variety 'plant', availables
    if cultivation = support.contents.where(type: Plant).of_variety(variant.variety).availables.reorder(:born_at).first
      cultivation
    end
  end

  def unified_size_unit
    size_unit_name.blank? ? :unity : size_unit_name
  end

  # Compute quantity of a support as defined in production
  def current_size(options = {})
    options[:at] ||= self.started_on ? self.started_on.to_time : Time.zone.now
    value = support.get(size_indicator_name, options)
    value = value.in(size_unit_name) if size_unit_name.present?
    value
  end

  def duplicate!(updates = {})
    new_attributes = %i[
      activity campaign cultivable_zone irrigated nitrate_fixing
      size_indicator_name size_unit_name size_value started_on
      support_nature support_shape usage
    ].each_with_object({}) do |attr, h|
      h[attr] = send(attr)
      h
    end.merge(updates)
    self.class.create!(new_attributes)
  end

  alias net_surface_area support_shape_area

  ## LABEL METHODS ##

  def work_name
    "#{support_work_number} - #{net_surface_area.convert(:hectare).round(2)}"
  end

  def human_area(unit = :hectare)
    if support_shape
      support_shape_area.convert(unit).round(2).l(precision: 2)
    end
  end

  def get(*args)
    if support.blank?
      raise StandardError.new("No support defined. Got: #{support.inspect}")
    end

    support.get(*args)
  end

  # # Returns value of an indicator if its name correspond to
  # def method_missing(method_name, *args)
  #   if Onoma::Indicator.include?(method_name.to_s)
  #     return get(method_name, *args)
  #   end
  #   super
  # end

  private def sowing_date_between_period_of_activity_production
    if predicated_sowing_date.present? && predicated_sowing_date < started_on
      errors.add(:predicated_sowing_date, :date_should_be_after_start_date_of_production)
    end

    if predicated_sowing_date.present? && predicated_sowing_date > stopped_on
      errors.add(:predicated_sowing_date, :date_should_be_before_end_of_production)
    end
  end

  private def support_shape_presence_if_vegetal_farming
    errors.add(:support_shape, :empty) if (plant_farming? || vine_farming?) && support_shape.blank?
  end

  private def stopped_on_after_last_intervention
    return if interventions.none?

    validates_date :stopped_on, after: ->{ interventions.order(:stopped_at).pluck(:stopped_at).last.to_date }
  end
end
