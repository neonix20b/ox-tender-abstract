module OxTenderAbstract
  class Engine < ::Rails::Engine
    isolate_namespace OxTenderAbstract # this is generally recommended

    # no other special configuration needed. But maybe you want
    # an initializer to be added to the app? Easy!
    # initializer 'yourgem.boot_stuff_up' do
    #   OxTenderAbstract.boot_something_up!
    # end
  end
end
