class LanguagePolicy < ApplicationPolicy
  def index?
    true
  end

  alias_method :show?, :index?

  def create?
    admin?
  end

  alias_method :update?, :create?
  alias_method :destroy?, :create?

  private

  def admin?
    !user.nil? && user.admin?
  end
end
