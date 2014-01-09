require 'spec_helper'
require 'support/mock_models/blog_post'
require 'support/mock_models/car'

describe ApiModel do

  describe "sending different types of requests" do
    before do
      BlogPost.api_config do |config|
        config.host = "http://api-model-specs.com"
      end
    end

    it "should be possible to send a GET request" do
      get_request = VCR.use_cassette('posts') { BlogPost.get_json "/single_post" }
      get_request.http_response.request_method.should eq :get
    end

    it "should be possible to send a POST request" do
      post_request = VCR.use_cassette('posts') { BlogPost.post_json "/posts" }
      post_request.http_response.request_method.should eq :post
    end

    it 'should be possible to send a PUT request' do
      put_request = VCR.use_cassette('posts') { BlogPost.put_json "/post/1" }
      put_request.http_response.request_method.should eq :put
    end

    it 'should be possible to send a POST request with a hash as body' do
      post_request = VCR.use_cassette('posts') { BlogPost.post_json "/create_with_json", name: "foobarbaz" }
      post_request.http_response.api_call.request.options[:body].should eq "{\"name\":\"foobarbaz\"}"
    end

    it 'should be possible to send a PUT request with a hash as body' do
      post_request = VCR.use_cassette('posts') { BlogPost.put_json "/post/1", name: "foobarbaz" }
      post_request.http_response.api_call.request.options[:body].should eq "{\"name\":\"foobarbaz\"}"
    end
  end

  describe "retrieving a single object" do
    describe "with the default builder" do
      let(:blog_post) do
        VCR.use_cassette('posts') do
          BlogPost.get_json "http://api-model-specs.com/single_post"
        end
      end

      it "should run the request and objectify the response hash" do
        blog_post.should be_a(BlogPost)
        blog_post.name.should eq "foo"
      end
    end

    describe "with a custom builder" do
      let(:custom_built_blog_post) do
        VCR.use_cassette('posts') do
          BlogPost.get_json "http://api-model-specs.com/single_post", {}, builder: BlogPost::CustomBuilder.new
        end
      end

      it "should be possible to use a custom builder class when objectifing" do
        custom_built_blog_post.should be_a(BlogPost)
        custom_built_blog_post.title.should eq "FOOBAR"
      end
    end
  end

  describe "using Hashie to build with properties" do
    describe "with a single object response" do
      let :car do
        VCR.use_cassette('cars') { Car.get_json "http://cars.com/one_convertable" }
      end

      it 'should build the correct object' do
        car.should be_a(Car)
      end

      it 'should correctly rename properties' do
        car.number_of_doors.should eq 2
      end

      it 'should correctly transform properties' do
        car.top_speed.should eq 600
      end

      it 'should let you define custom methods as normal' do
        car.is_fast?.should be_true
      end

      it 'should let you respect default values for properties' do
        car.name.should eq "Ferrari"
      end
    end

    describe "with a collection of objects response" do
      let :cars do
        VCR.use_cassette('cars') { Car.get_json "http://cars.com/fast_ones" }
      end

      it 'should build an array of the correct objects' do
        cars.should be_a(Array)
        cars.collect { |car| car.should be_a(Car) }
      end

      it 'should correctly rename properties' do
        cars.last.number_of_doors.should eq 4
      end

      it 'should correctly transform properties' do
        cars.last.top_speed.should eq 300
      end

      it 'should let you define custom methods as normal' do
        cars.last.is_fast?.should be_false
      end

      it 'should respect default values for properties, but also override them' do
        cars.first.name.should eq "Ferrari"
        cars.last.name.should eq "Ford"
      end
    end

    describe "with a single object which has properties which are undefined" do
      let :new_car do
        VCR.use_cassette('cars') { Car.get_json "http://cars.com/new_model" }
      end

      it "should not raise an exception" do
        expect {
          new_car
        }.to_not raise_error
      end

      it 'should define the missing property on the fly' do
        new_car.shiney.should eq true
      end
    end
  end

  describe "setting errors from a hash" do
    let(:car) { Car.new }
    let(:blog_post) { BlogPost.new }

    it 'should assign errors from a simple hash using active model errors' do
      car.set_errors_from_hash name: "Is invalid"
      car.errors[:name].should eq ["Is invalid"]
    end

    it 'should assign multiple errors from an array' do
      car.set_errors_from_hash top_speed: ["is too fast", "would break the sound barrier"]
      car.errors[:top_speed].size.should eq 2
    end

    it 'should be possible to assign the errors to other classes' do
      car.set_errors_from_hash({ name: "is bad" }, blog_post)
      car.errors.size.should eq 0
      blog_post.errors[:name].should eq ["is bad"]
    end
  end

  describe "updating attributes from a hash" do
    let(:car) { Car.new }

    it 'should change an existing attribute' do
      car.name = "Chevvy"
      expect {
        car.update_attributes_from_hash name: "Ford"
      }.to change{ car.name }.from("Chevvy").to("Ford")
    end

    it 'should set an attribute if unset' do
      expect {
        car.update_attributes_from_hash number_of_doors: 2
      }.to change{ car.number_of_doors }.from(nil).to(2)
    end

    it 'should log if the attribute is not defined' do
      ApiModel::Log.should_receive(:debug).with "Could not set age on Car"
      car.update_attributes_from_hash age: 2
    end
  end

  describe "saving changes on an instance" do
    before do
      BlogPost.api_config { |config| config.host = "http://api-model-specs.com" }
    end

    let(:blog_post) { BlogPost.new }

    # VCR will blow up if this was not a PUT, so no rspec expectations are needed here...
    it 'should send a PUT request' do
      VCR.use_cassette('posts') { blog_post.save "/post/1" }
    end

    # Same again here with VCR...
    it 'should be possible to change the request type' do
      VCR.use_cassette('posts') { blog_post.save "/post/update_with_post", nil, request_method: :post }
    end

    it 'should be possible to send a JSON body in the same way a normal POST or PUT request would' do
      VCR.use_cassette('posts') { blog_post.save "/post/2", name: "foobarbaz" }
    end

    it 'should use #update_attributes_from_hash using the response body to update the instance' do
      blog_post.should_receive(:update_attributes_from_hash).with "name" => "foobarbaz"
      VCR.use_cassette('posts') { blog_post.save "/post/2", name: "foobarbaz" }
    end

    describe "callbacks" do
      class BlogPost
        after_save :saved
        after_successful_save :yay_it_saved
        after_unsuccessful_save :oh_no_it_didnt_save

        def saved; end
        def yay_it_saved; end
        def oh_no_it_didnt_save; end
      end

      it 'should run a callback around the whole save method' do
        blog_post.should_receive(:saved).once
        VCR.use_cassette('posts') { blog_post.save "/post/1" }
      end

      it 'should run a callback around the handling of a successful response' do
        blog_post.should_receive(:yay_it_saved).once
        VCR.use_cassette('posts') { blog_post.save "/post/1" }
      end

      # TODO - come back to this. Apparently something is causing #errors on blog_post to be nil, which makes it explode
      #it 'should run a callback around the handling of a unsuccessful response' do
      #  blog_post.should_receive(:oh_no_it_didnt_save).once
      #  VCR.use_cassette('posts') { blog_post.save "/post/with_errors", name: "" }
      #end
    end
  end

  describe "cache_id" do
    it 'should use options and the request path to create an identifier for the cache' do
      BlogPost.cache_id("/box", params: { foo: "bar" }).should eq "/boxfoobar"
    end
  end

end