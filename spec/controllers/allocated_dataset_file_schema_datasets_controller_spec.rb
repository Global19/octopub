require 'rails_helper'
require 'support/odlifier_licence_mock'

describe AllocatedDatasetFileSchemaDatasetsController, type: :controller do
  include_context 'odlifier licence mock'

  let(:dataset_name) { "My cool dataset" }
  let(:description) { "This is a description" }
  let(:publisher_name) { "Cool inc"}
  let(:publisher_url) { "http://example.com"}
  let(:license) { "OGL-UK-3.0" }
  let(:frequency) { "Monthly" }
  let(:filename) { 'valid-schema.csv' }
  let(:storage_key) { filename }
  let(:url_for_data_file) { url_with_stubbed_get_for_storage_key(storage_key, filename) }
  let(:not_matching_filename) { 'invalid-schema.csv' }
  let(:not_matching_storage_key) { not_matching_filename }
  let(:url_for_not_matching_data_file) { url_with_stubbed_get_for_storage_key(not_matching_storage_key, not_matching_storage_key) }
  let(:schema_path) { get_fixture_schema_file('good-schema.json') }

  before(:each) do
    Sidekiq::Testing.inline!

    @user = create(:user)
    sign_in @user
    allow_any_instance_of(JekyllService).to receive(:create_data_files) { nil }
    allow_any_instance_of(JekyllService).to receive(:create_jekyll_files) { nil }
    allow_any_instance_of(CreateRepository).to receive(:perform)

    @url_for_schema = url_for_schema_with_stubbed_get_for(schema_path)

    @dataset_file_schema = DatasetFileSchemaService.new(
      'existing schema',
      'existing schema description',
      @url_for_schema,
      @user,
      @user.name
    ).create_dataset_file_schema

    @files ||= []
  end

  after(:each) do
    Sidekiq::Testing.fake!
  end

  describe 'create dataset with an existing schema' do
    context 'returns an error if the file does not match the schema' do

      before(:each) do
        @files << {
          title: 'My File',
          description: 'My Description',
          file: url_for_not_matching_data_file,
          storage_key: not_matching_storage_key,
          dataset_file_schema_id: @dataset_file_schema.id
        }

        @dataset = {
          name: dataset_name,
          description: description,
          publisher_name: publisher_name,
          publisher_url: publisher_url,
          license: license,
          frequency: frequency
        }
      end
    end

    it 'creates sucessfully if the file matches the schema' do

      @files << {
        title: 'My File',
        description: 'My Description',
        file: url_for_data_file,
        storage_key: storage_key,
        dataset_file_schema_id: @dataset_file_schema.id
      }
      request = post :create, params: { dataset: {
        name: dataset_name,
        description: description,
      }, files: @files, dataset_file_schema_id: @dataset_file_schema.id }

      expect(request).to redirect_to(created_datasets_path)
      expect(Dataset.count).to eq(1)
      expect(DatasetFileSchema.count).to eq(1)

      expect(@user.dataset_file_schemas.count).to eq(1)
      expect(@user.datasets.count).to eq(1)
      expect(@user.datasets.first.dataset_files.count).to eq(1)

      expect(@user.datasets.first.dataset_files.first.dataset_file_schema.url).to eq(@url_for_schema)
    end

    it 'creates sucessfully if the file matches the schema and returns 202 if async' do

      @files << {
        title: 'My File',
        description: 'My Description',
        file: url_for_data_file,
        storage_key: storage_key,
        dataset_file_schema_id: @dataset_file_schema.id
      }
      request = post :create, params: { dataset: {
        name: dataset_name,
        description: description,
      }, files: @files, dataset_file_schema_id: @dataset_file_schema.id, async: true }

      expect(response.code).to eq("202")
    end
  end
end
