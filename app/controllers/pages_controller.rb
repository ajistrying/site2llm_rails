class PagesController < ApplicationController
  def home
    @price_usd = ::Llms::Generate::PRICE_USD
    @site_types = ::Llms::Generate::SITE_TYPES
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
    @price_usd = ::Llms::Generate::PRICE_USD
  end
end
