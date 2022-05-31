class OrdersController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:update, :done]
    before_action :set_user, except: [:update, :done]

    def index
        order = @user.orders.create(name: "plan_pro", email: @user.email, amount: 100)
        # @return_url = "#{request.protocol}#{request.host_with_port}#{orders_update_path}"
        # @notify_url = "#{request.protocol}#{request.host_with_port}#{orders_update_path}"
        @form_info = Newebpay::Mpg.new(order).form_info    
        # render html: [@return_url,@notify_url, @form_info]
    end
        
    def create
    end
    
    def update
        response = Newebpay::Mpgresponse.new(params[:TradeInfo])
        order = Order.last
        order.update(resp: [response, params])
    end
    
    def done
        response = Newebpay::Mpgresponse.new(params[:TradeInfo])
        render html: response
    end
    
    private
    def set_user
      @user = User.find(params[:user_id])
    end

end