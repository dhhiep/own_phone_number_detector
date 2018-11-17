class HomeController < ApplicationController
  def index
    @results = [
      {
          name: 'Hiep',
          phone: '11234'
      }, {
        name: 'Hiep2',
        phone: '11234'
      }
    ]
  end
end
