# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"
require "contracts/shared/model_contract_shared_context"

RSpec.describe ProjectLifeCycleSteps::BaseContract do
  include_context "ModelContract shared context"

  let(:contract) { described_class.new(project, user) }
  let(:project) { build_stubbed(:project) }

  context "with authorized user" do
    let(:user) { build_stubbed(:user) }
    let(:project) { build_stubbed(:project, available_life_cycle_steps: steps) }
    let(:steps) { [] }

    before do
      mock_permissions_for(user) do |mock|
        mock.allow_in_project(:edit_project_stages_and_gates, project:)
      end
    end

    it_behaves_like "contract is valid"
    include_examples "contract reuses the model errors"

    describe "validations" do
      describe "#consecutive_steps_have_increasing_dates" do
        let(:step1) { build_stubbed(:project_gate, start_date: Date.new(2024, 1, 1)) }
        let(:step2) { build_stubbed(:project_stage, start_date: Date.new(2024, 2, 1), end_date: Date.new(2024, 2, 28)) }
        let(:step3) { build_stubbed(:project_gate, start_date: Date.new(2024, 3, 1), end_date: Date.new(2024, 3, 15)) }
        let(:steps) { [step1, step2, step3] }

        context "when no steps are present" do
          let(:steps) { [] }

          it_behaves_like "contract is valid"
        end

        context "when only one step is present" do
          let(:steps) { [step1] }

          it_behaves_like "contract is valid"
        end

        context "when steps have valid and increasing dates" do
          let(:steps) { [step1, step2] }

          it_behaves_like "contract is valid"
        end

        context "when steps have decreasing dates" do
          context "and the erroneous step is a Gate" do
            let(:steps) { [step3, step1] }

            it_behaves_like "contract is invalid",
                            "available_life_cycle_steps.date": :non_continuous_dates

            it "adds an error to the decreasing step" do
              contract.validate
              expect(step1.errors.symbols_for(:date)).to include(:non_continuous_dates)
            end
          end

          context "and the erroneous step is a Stage" do
            let(:steps) { [step3, step2] }

            it_behaves_like "contract is invalid",
                            "available_life_cycle_steps.date_range": :non_continuous_dates

            it "adds an error to the decreasing step" do
              contract.validate
              expect(step2.errors.symbols_for(:date_range)).to include(:non_continuous_dates)
            end
          end
        end

        context "when steps with identical dates" do
          let(:step4) { build_stubbed(:project_gate, start_date: Date.new(2024, 1, 1)) }
          let(:steps) { [step1, step4] }

          it_behaves_like "contract is invalid",
                          "available_life_cycle_steps.date": :non_continuous_dates
        end

        context "when a step has missing start dates" do
          let(:step_missing_dates) { build_stubbed(:project_stage, start_date: nil, end_date: nil) }

          context "and the other steps have increasing dates" do
            let(:steps) { [step1, step_missing_dates, step2] }

            it_behaves_like "contract is invalid",
                            "available_life_cycle_steps.date_range": :blank
          end

          context "and the other steps have decreasing dates" do
            let(:steps) { [step2, step_missing_dates, step1] }

            it_behaves_like "contract is invalid",
                            "available_life_cycle_steps.date": :non_continuous_dates

            it "adds an error to the decreasing step" do
              contract.validate
              expect(step1.errors.symbols_for(:date)).to include(:non_continuous_dates)
            end
          end
        end
      end

      describe "triggering validations on the model" do
        it "sets the :saving_life_cycle_steps validation context" do
          allow(project).to receive(:valid?)

          contract.validate
          expect(project).to have_received(:valid?).with(:saving_life_cycle_steps)
        end
      end
    end
  end

  context "with unauthorized user" do
    let(:user) { build_stubbed(:user) }

    it_behaves_like "contract user is unauthorized"
  end
end
