class PagesController < ApplicationController
  def home
    @price_usd = LlmsGenerator::PRICE_USD
    @site_types = LlmsGenerator::SITE_TYPES
  end

  def success
    @run_id = params[:runId]
    redirect_to root_path and return if @run_id.blank?

    @run = LlmsRun.find_active(@run_id)
    if @run.nil?
      flash[:error] = "Run not found. It may have expired."
      redirect_to root_path and return
    end

    @paid = @run.paid?
    @content = @paid ? @run.content : nil
    @price_usd = LlmsGenerator::PRICE_USD
  end
end
