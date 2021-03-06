#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'
require File.join(Rails.root, 'lib/diaspora/exporter')

describe Diaspora::Exporter do

  before do
    @user1 =  make_user
    @user2 =  make_user
    @user3 =  make_user

    @aspect  =  @user1.aspects.create(:name => "Old Work")
    @aspect1 =  @user1.aspects.create(:name => "Work")
    @aspect2 =  @user2.aspects.create(:name => "Family")
    @aspect3 =  @user3.aspects.create(:name => "Pivots")

    @status_message1 =  @user1.post(:status_message, :message => "One", :public => true, :to => @aspect1.id)
    @status_message2 =  @user1.post(:status_message, :message => "Two", :public => true, :to => @aspect1.id)
    @status_message3 =  @user2.post(:status_message, :message => "Three", :public => false, :to => @aspect2.id)

    @user1.reload
    @user2.reload
  end

  def exported
    Nokogiri::XML(Diaspora::Exporter.new(Diaspora::Exporters::XML).execute(@user1))
  end

  context '<user/>' do
    before do
      @user_xml = exported.xpath('//user').to_s
    end
    it 'should include a users private key' do
      @user_xml.to_s.should include @user1.serialized_private_key
    end
  end

  context '<aspects/>' do

    it 'should include the post_ids' do
      aspects_xml = exported.xpath('//aspects').to_s
      aspects_xml.should include @status_message1.id.to_s
      aspects_xml.should include @status_message2.id.to_s
    end
  end

  context '<contacts/>' do

    before do
      connect_users(@user1, @aspect1, @user3, @aspect3)
      @user1.add_person_to_aspect(@user3.person.id, @aspect.id)
      @user1.reload
    end

    let(:contacts_xml) {exported.xpath('//contacts').to_s}
    it 'should include a person id' do
      contacts_xml.should include @user3.person.id.to_s
    end

    it 'should include an aspects names of all aspects they are in' do
      #contact specific xml needs to be tested
      @user1.contacts.find_by_person_id(@user3.person.id).aspects.count.should > 0
      @user1.contacts.find_by_person_id(@user3.person.id).aspects.each { |aspect|
        contacts_xml.should include aspect.name
      }
    end
  end

  context '<people/>' do
    let(:people_xml) {exported.xpath('//people').to_s}
    before do
      connect_users(@user1, @aspect1, @user3, @aspect3)
      @user1.reload
    end
    it 'should include persons id' do
      people_xml.should include @user3.person.id.to_s
    end

    it 'should include their profile' do
      people_xml.should include @user3.person.profile.first_name
      people_xml.should include @user3.person.profile.last_name
    end

    it 'should include their public key' do
      people_xml.should include @user3.person.exported_key
    end

    it 'should include their diaspora handle' do
      people_xml.should include @user3.person.diaspora_handle
    end
  end

  context '<posts>' do
    let(:posts_xml) {exported.xpath('//posts').to_s}
    it 'should include many posts xml' do
      posts_xml.should include @status_message1.message
      posts_xml.should include @status_message2.message
      posts_xml.should_not include @status_message3.message
    end

    it 'should include post created at time' do
      doc = Nokogiri::XML::parse(posts_xml)
      Time.parse(doc.xpath('//posts/status_message/created_at').first.text).should == @status_message1.created_at
    end
  end
end
