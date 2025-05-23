# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2015 Brice Texier, David Joulin
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class SaleOpportunitiesController < Backend::SaleAffairsController
    manage_restfully currency: 'Preference[:currency]'.c, responsible: 'current_user.person'.c, probability_percentage: 50

    respond_to :csv, :ods, :xlsx, :pdf, :odt, :docx, :html, :xml, :json

    # management -> sales_conditions
    def self.conditions
      code = ''
      code = search_conditions(sale_opportunities: %i[pretax_amount number description], entities: %i[number full_name]) + " ||= []\n"
      code << "if params[:responsible_id].to_i > 0\n"
      code << "  c[0] += \" AND \#{SaleOpportunity.table_name}.responsible_id = ?\"\n"
      code << "  c << params[:responsible_id]\n"
      code << "end\n"
      code << "if params[:provider_id].to_i > 0\n"
      code << "  c[0] += \" AND \#{SaleOpportunity.table_name}.provider_id = ?\"\n"
      code << "  c << params[:provider_id]\n"
      code << "end\n"
      code << "if params[:nature_id].to_i > 0\n"
      code << "  c[0] += \" AND \#{SaleOpportunity.table_name}.nature_id = ?\"\n"
      code << "  c << params[:nature_id]\n"
      code << "end\n"
      code << "if params[:state].is_a?(Array) && !params[:state].empty?\n"
      code << "  c[0] << ' AND #{SaleOpportunity.table_name}.state IN (?)'\n"
      code << "  c << params[:state]\n"
      code << "end\n"
      code << "c\n "
      code.c
    end

    list(conditions: conditions, joins: :client, order: { created_at: :desc, number: :desc }) do |t|
      t.action :edit
      t.action :destroy
      t.column :number, url: true
      t.column :nature
      t.column :name
      t.column :created_at
      t.column :dead_line_at
      t.column :client, url: true
      t.column :responsible, hidden: true
      t.column :description, hidden: true
      t.column :provider, hidden: true
      t.status
      t.column :state_label, hidden: true
      t.column :pretax_amount, currency: true
      t.column :probability_percentage
    end

    list(:tasks, conditions: { sale_opportunity_id: 'params[:id]'.c }, order: :state, line_class: 'RECORD.state'.c) do |t|
      t.action :edit
      t.action :destroy
      t.column :name, url: true
      t.column :nature
      t.status
      t.column :due_at
      t.column :executor, url: true
      t.column :entity, url: true
    end

    list(:sale_contracts, conditions: { sale_opportunity_id: 'params[:id]'.c }) do |t|
      t.action :edit
      t.action :destroy, if: :destroyable?
      t.column :name, url: true
      t.column :pretax_amount
      t.column :responsible
    end

    list(:events, conditions: { affair_id: 'params[:id]'.c }, order: :started_at) do |t|
      t.action :edit
      t.action :destroy
      t.column :name, url: true
      t.column :started_at
      t.column :nature
      t.column :duration
      t.column :place
    end

    SaleOpportunity.state_machine.events.each do |event|
      define_method event.name do
        fire_event(event.name)
      end
    end
  end
end
