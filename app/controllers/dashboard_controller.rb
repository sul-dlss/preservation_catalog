# frozen_string_literal: true

# Minimal controller for dashboard
class DashboardController < ApplicationController
  def index; end # 3 nav bar tabs as pills

  def index2; end # 3 nav bar tabs, aligned bottom of tab

  def index3; end # 2 nav bar tabs as (old ugly) cards

  def index4; end # nav bar is drop downs

  def index5; end # nav bar is pills on the side

  def index6; end # use fixed sidebar for nav
end
