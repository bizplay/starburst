# frozen_string_literal: true

RSpec.describe Starburst::AnnouncementsController do
  routes { Starburst::Engine.routes }

  describe '#mark_as_read' do
    subject(:mark_as_read) do
      if Rails::VERSION::MAJOR < 5
        post :mark_as_read, **params
      else
        post :mark_as_read, params: params
      end
    end

    let(:announcement) { create(:announcement) }
    let(:params) { Hash[id: announcement.id] }

    before { allow(controller).to receive(:current_user).and_return(current_user) }

    context 'with a signed in user' do
      let(:current_user) { create(:user) }

      context 'when the user has not marked the announcement as read yet' do
        let(:announcement_view) { an_object_having_attributes(user_id: current_user.id) }

        it { expect(mark_as_read).to have_http_status(:ok) }

        it 'marks the announcement as viewed by the signed in user' do
          expect { mark_as_read }.to change(Starburst::AnnouncementView, :all).to contain_exactly(announcement_view)
        end
      end

      context 'when the user has already marked the announcement as read' do
        before { create(:announcement_view, user_id: current_user.id, announcement: announcement) }

        it { expect(mark_as_read).to have_http_status(:ok) }
        it { expect { mark_as_read }.not_to change(Starburst::AnnouncementView, :count) }
      end
    end

    context 'without a signed in user' do
      let(:current_user) { nil }

      it { expect(mark_as_read).to have_http_status(:unprocessable_entity) }
      it { expect { mark_as_read }.not_to change(Starburst::AnnouncementView, :count) }
    end
  end

  describe '#index' do
    subject(:index) do
      if Rails::VERSION::MAJOR < 5
        get :index, **params
      else
        get :index, params: params
      end
    end

    let(:announcement1) { create(:announcement, title: "Announcement 1") }
    let(:announcement2) { create(:announcement, title: "Announcement 2") }
    let(:announcement3) { create(:announcement, title: "Announcement 3") }
    let(:params) { {} }

    before { allow(controller).to receive(:current_user).and_return(current_user) }

    context 'with a signed in user' do
      let(:current_user) { create(:user) }

      context 'when the user has not marked the announcement as read yet' do
        it { expect(index).to have_http_status(:ok) }

        it 'returns a JSON hash of the three announcements' do
          index
          parsed_response = JSON.parse(response.body)
          expect(parsed_response.size).to eq(3)
        end
      end

      context 'when the user has already marked the announcement as read' do
        before { create(:announcement_view, user_id: current_user.id, announcement: announcement2) }

        it 'returns a JSON hash of the three announcements with one marked as read' do
          index
          parsed_response = JSON.parse(response.body)
          expect(parsed_response.size).to eq(3)
        end
      end
    end

    context 'without a signed in user' do
      let(:current_user) { nil }

      it { expect(index).to have_http_status(:unprocessable_entity) }
    end
  end
end
