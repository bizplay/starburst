# frozen_string_literal: true

RSpec.describe Starburst::Announcement do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
  end

  describe '.current' do
    subject(:current) { described_class.current(user) }

    let(:user) { create(:user) }

    shared_examples 'oldest unread announcement' do
      it { is_expected.to eq(first_announcement) }

      context 'when a previous announcement has already been seen' do
        before { create(:announcement_view, user: user, announcement: first_announcement) }

        it { is_expected.to eq(second_announcement) }
      end
    end

    context 'when the provided user is nil' do
      let(:user) { nil }
      let(:message) { 'User is required to find current announcement' }

      it { expect { current }.to raise_error(ArgumentError).with_message(message) }
    end

    context 'when it is expired' do
      before { create(:announcement, stop_delivering_at: 1.minute.ago) }

      it { is_expected.to be_nil }
    end

    context 'when it is not expired yet' do
      let!(:first_announcement) do
        create(
          :announcement,
          start_delivering_at: 2.minutes.ago,
          stop_delivering_at: 10.minutes.from_now
        )
      end
      let!(:second_announcement) do
        create(
          :announcement,
          start_delivering_at: 1.minute.ago,
          stop_delivering_at: 10.minutes.from_now
        )
      end

      include_examples 'oldest unread announcement'
    end

    context 'when it is due' do
      let!(:first_announcement) { create(:announcement, start_delivering_at: 2.minutes.ago) }
      let!(:second_announcement) { create(:announcement, start_delivering_at: 1.minute.ago) }

      include_examples 'oldest unread announcement'
    end

    context 'when it is not due yet' do
      before { create(:announcement, start_delivering_at: 1.minute.from_now) }

      it { is_expected.to be_nil }
    end

    context 'when no timestamps are set' do
      let!(:first_announcement) { create(:announcement, start_delivering_at: nil, stop_delivering_at: nil) }
      let!(:second_announcement) { create(:announcement, start_delivering_at: nil, stop_delivering_at: nil) }

      include_examples 'oldest unread announcement'
    end

    context 'when there are announcements with an attribute condition' do
      let!(:first_announcement) do
        create(
          :announcement,
          start_delivering_at: 2.minutes.ago,
          limit_to_users: [
            {
              field: 'subscription',
              value: 'weekly'
            }
          ]
        )
      end
      let!(:second_announcement) do
        create(
          :announcement,
          start_delivering_at: 1.minutes.ago,
          limit_to_users: [
            {
              field: 'subscription',
              value: 'weekly'
            }
          ]
        )
      end

      context 'when the user should see the announcements' do
        let(:user) { create(:user, subscription: 'weekly') }

        include_examples 'oldest unread announcement'
      end

      context 'when the user should not see the announcements' do
        let(:user) { create(:user, subscription: 'monthly') }

        it { is_expected.to be_nil }
      end
    end

    context 'when there are announcements with a method condition' do
      let!(:first_announcement) do
        create(
          :announcement,
          start_delivering_at: 2.minutes.ago,
          limit_to_users: [
            {
              field: 'free?',
              value: true
            }
          ]
        )
      end
      let!(:second_announcement) do
        create(
          :announcement,
          start_delivering_at: 1.minute.ago,
          limit_to_users: [
            {
              field: 'free?',
              value: true
            }
          ]
        )
      end

      before { allow(Starburst).to receive(:user_instance_methods).and_return(%i[free?]) }

      context 'when the user should see the announcement' do
        let(:user) { create(:user, subscription: '') }

        include_examples 'oldest unread announcement'
      end

      context 'when the user should not see the announcement' do
        let(:user) { create(:user, subscription: 'monthly') }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.in_delivery_order' do
    subject { described_class.in_delivery_order }

    let!(:first_announcement) { create(:announcement, start_delivering_at: 2.minutes.ago) }
    let!(:second_announcement) { create(:announcement, start_delivering_at: 1.minute.ago) }

    it { is_expected.to eq([first_announcement, second_announcement]) }
  end

  describe '.ready_for_delivery' do
    subject { described_class.ready_for_delivery }

    let!(:due_announcement) { create(:announcement, start_delivering_at: 1.minute.ago) }
    let!(:not_due_announcement) { create(:announcement, start_delivering_at: 1.minute.from_now) }
    let!(:expired_announcement) { create(:announcement, stop_delivering_at: 1.minute.ago) }
    let!(:not_expired_announcement) { create(:announcement, stop_delivering_at: 1.minute.from_now) }
    let!(:unscheduled_announcement) { create(:announcement, start_delivering_at: nil, stop_delivering_at: nil) }

    it { is_expected.to contain_exactly(due_announcement, not_expired_announcement, unscheduled_announcement) }
  end

  describe '.unread_by' do
    subject { described_class.unread_by(current_user) }

    let(:current_user) { create(:user) }
    let(:another_user) { create(:user) }
    let(:announcement1) { create(:announcement) }
    let(:announcement2) { create(:announcement) }

    before do
      create(:announcement_view, user: another_user, announcement: announcement1)
      create(:announcement_view, user: current_user, announcement: announcement2)
    end

    it { is_expected.to contain_exactly(announcement1) }
  end

  describe '.find_announcement_for_current_user' do
    subject { described_class.find_announcement_for_current_user(described_class.all, user) }

    context 'with an attribute condition' do
      let!(:announcement) do
        create(
          :announcement,
          limit_to_users: [
            {
              field: 'subscription',
              value: 'weekly'
            }
          ]
        )
      end

      context 'when the user should see the announcement' do
        let(:user) { create(:user, subscription: 'weekly') }

        it { is_expected.to eq(announcement) }
      end

      context 'when the user should not see the announcement' do
        let(:user) { create(:user, subscription: 'monthly') }

        it { is_expected.to be_nil }
      end
    end

    context 'with a method condition' do
      let!(:announcement) do
        create(
          :announcement,
          limit_to_users: [
            {
              field: 'free?',
              value: true
            }
          ]
        )
      end

      before { allow(Starburst).to receive(:user_instance_methods).and_return(%i[free?]) }

      context 'when the user should see the announcement' do
        let(:user) { create(:user, subscription: '') }

        it { is_expected.to eq(announcement) }
      end

      context 'when the user should not see the announcement' do
        let(:user) { create(:user, subscription: 'monthly') }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.all_recent_for' do
    let(:current_user) { create(:user) }
    let(:another_user) { create(:user) }
    let!(:announcement1) { create(:announcement) }
    let!(:announcement2) { create(:announcement, category: "en") }
    let!(:old_announcement1) { create(:announcement, start_delivering_at: 20.days.ago) }
    let!(:old_announcement2) { create(:announcement, created_at: 3.weeks.ago) }

    before do
      create(:announcement_view, user: current_user, announcement: announcement2)
    end

    context 'for current user with no specific start time specified' do
      subject { described_class.all_recent_for(current_user) }

      it { is_expected.to contain_exactly(announcement1, announcement2) }
    end

    context 'for current user with a start time of 4 weeks ago' do
      subject { described_class.all_recent_for(current_user, 4.weeks.ago) }

      it { is_expected.to contain_exactly(announcement1, announcement2, old_announcement1, old_announcement2) }

      it { is_expected.to contain_exactly(
        an_object_having_attributes(read: 0),
        an_object_having_attributes(read: 0),
        an_object_having_attributes(read: 0),
        an_object_having_attributes(read: 1)
      ) }
    end

    context 'for another user with a start time of 4 weeks ago' do
      subject { described_class.all_recent_for(another_user, 4.weeks.ago) }

      it { is_expected.not_to include(an_object_having_attributes(viewed: 1)) }
    end

    context 'for current user with no start time 2 weeks ago and category "en"' do
      subject { described_class.all_recent_for(current_user, 2.weeks.ago, "en") }

      it { is_expected.to contain_exactly(announcement2) }
    end
  end
end
