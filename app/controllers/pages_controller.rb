class PagesController < ApplicationController
  def home
    set_meta_tags title: "llms.txt for AI search",
                  description: "Generate llms.txt so AI search reads your site correctly. Answer a few questions, get a clean llms.txt you can publish in minutes.",
                  og: { title: "site2llm - llms.txt for AI search" },
                  twitter: { title: "site2llm - llms.txt for AI search" }

    @price_usd = ::Llms::Generate::PRICE_USD
    @site_types = ::Llms::Generate::SITE_TYPES
  end

  def success
    set_meta_tags title: "Download your llms.txt",
                  description: "Your llms.txt is ready. Download and publish it to your site root.",
                  og: { title: "Download your llms.txt - site2llm" },
                  twitter: { title: "Download your llms.txt - site2llm" }

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
