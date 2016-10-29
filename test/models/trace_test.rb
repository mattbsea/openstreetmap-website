require "test_helper"
require "digest"
require "minitest/mock"

class TraceTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @gpx_trace_dir = Object.send("remove_const", "GPX_TRACE_DIR")
    Object.const_set("GPX_TRACE_DIR", File.dirname(__FILE__) + "/../traces")

    @gpx_image_dir = Object.send("remove_const", "GPX_IMAGE_DIR")
    Object.const_set("GPX_IMAGE_DIR", File.dirname(__FILE__) + "/../traces")
  end

  def teardown
    Object.send("remove_const", "GPX_TRACE_DIR")
    Object.const_set("GPX_TRACE_DIR", @gpx_trace_dir)

    Object.send("remove_const", "GPX_IMAGE_DIR")
    Object.const_set("GPX_IMAGE_DIR", @gpx_image_dir)
  end

  def test_visible
    public_trace_file = create(:trace)
    create(:trace, :deleted)
    check_query(Trace.visible, [public_trace_file])
  end

  def test_visible_to
    public_trace_file = create(:trace, :visibility => "public", :user => users(:normal_user))
    anon_trace_file = create(:trace, :visibility => "private", :user => users(:public_user))
    identifiable_trace_file = create(:trace, :visibility => "identifiable", :user => users(:normal_user))
    pending_trace_file = create(:trace, :visibility => "public", :user => users(:public_user), :inserted => false)
    trackable_trace_file = create(:trace, :visibility => "trackable", :user => users(:public_user))
    _other_trace_file = create(:trace, :visibility => "private", :user => users(:second_public_user))

    check_query(Trace.visible_to(users(:normal_user).id), [
                  public_trace_file, identifiable_trace_file, pending_trace_file
                ])
    check_query(Trace.visible_to(users(:public_user)), [
                  public_trace_file, anon_trace_file, trackable_trace_file,
                  identifiable_trace_file, pending_trace_file
                ])
    check_query(Trace.visible_to(users(:inactive_user)), [
                  public_trace_file, identifiable_trace_file, pending_trace_file
                ])
  end

  def test_visible_to_all
    public_trace_file = create(:trace, :visibility => "public")
    _private_trace_file = create(:trace, :visibility => "private")
    identifiable_trace_file = create(:trace, :visibility => "identifiable")
    _trackable_trace_file = create(:trace, :visibility => "trackable")
    deleted_trace_file = create(:trace, :deleted, :visibility => "public")
    pending_trace_file = create(:trace, :visibility => "public", :inserted => false)

    check_query(Trace.visible_to_all, [
                  public_trace_file, identifiable_trace_file,
                  deleted_trace_file, pending_trace_file
                ])
  end

  def test_tagged
    london_trace_file = create(:trace) do |trace|
      create(:tracetag, :trace => trace, :tag => "London")
    end
    birmingham_trace_file = create(:trace) do |trace|
      create(:tracetag, :trace => trace, :tag => "Birmingham")
    end
    check_query(Trace.tagged("London"), [london_trace_file])
    check_query(Trace.tagged("Birmingham"), [birmingham_trace_file])
    check_query(Trace.tagged("Unknown"), [])
  end

  def test_validations
    trace_valid({})
    trace_valid({ :user_id => nil }, false)
    trace_valid(:name => "a" * 255)
    trace_valid({ :name => "a" * 256 }, false)
    trace_valid({ :description => nil }, false)
    trace_valid(:description => "a" * 255)
    trace_valid({ :description => "a" * 256 }, false)
    trace_valid(:visibility => "private")
    trace_valid(:visibility => "public")
    trace_valid(:visibility => "trackable")
    trace_valid(:visibility => "identifiable")
    trace_valid({ :visibility => "foo" }, false)
  end

  def test_tagstring
    trace = build(:trace)
    trace.tagstring = "foo bar baz"
    assert trace.valid?
    assert_equal 3, trace.tags.length
    assert_equal "foo", trace.tags[0].tag
    assert_equal "bar", trace.tags[1].tag
    assert_equal "baz", trace.tags[2].tag
    assert_equal "foo, bar, baz", trace.tagstring
    trace.tagstring = "foo, bar baz ,qux"
    assert trace.valid?
    assert_equal 3, trace.tags.length
    assert_equal "foo", trace.tags[0].tag
    assert_equal "bar baz", trace.tags[1].tag
    assert_equal "qux", trace.tags[2].tag
    assert_equal "foo, bar baz, qux", trace.tagstring
  end

  def test_public?
    assert_equal true, build(:trace, :visibility => "public").public?
    assert_equal false, build(:trace, :visibility => "private").public?
    assert_equal false, build(:trace, :visibility => "trackable").public?
    assert_equal true, build(:trace, :visibility => "identifiable").public?
    assert_equal true, build(:trace, :deleted, :visibility => "public").public?
  end

  def test_trackable?
    assert_equal false, build(:trace, :visibility => "public").trackable?
    assert_equal false, build(:trace, :visibility => "private").trackable?
    assert_equal true, build(:trace, :visibility => "trackable").trackable?
    assert_equal true, build(:trace, :visibility => "identifiable").trackable?
    assert_equal false, build(:trace, :deleted, :visibility => "public").trackable?
  end

  def test_identifiable?
    assert_equal false, build(:trace, :visibility => "public").identifiable?
    assert_equal false, build(:trace, :visibility => "private").identifiable?
    assert_equal false, build(:trace, :visibility => "trackable").identifiable?
    assert_equal true, build(:trace, :visibility => "identifiable").identifiable?
    assert_equal false, build(:trace, :deleted, :visibility => "public").identifiable?
  end

  def test_mime_type
    # The ids refer to the .gpx fixtures in test/traces
    check_mime_type(1, "application/gpx+xml")
    check_mime_type(2, "application/gpx+xml")
    check_mime_type(3, "application/x-bzip2")
    check_mime_type(4, "application/x-gzip")
    check_mime_type(6, "application/x-zip")
    check_mime_type(7, "application/x-tar")
    check_mime_type(8, "application/x-gzip")
    check_mime_type(9, "application/x-bzip2")
  end

  def test_extension_name
    # The ids refer to the .gpx fixtures in test/traces
    check_extension_name(1, ".gpx")
    check_extension_name(2, ".gpx")
    check_extension_name(3, ".gpx.bz2")
    check_extension_name(4, ".gpx.gz")
    check_extension_name(6, ".zip")
    check_extension_name(7, ".tar")
    check_extension_name(8, ".tar.gz")
    check_extension_name(9, ".tar.bz2")
  end

  def test_xml_file
    check_xml_file(1, "848caa72f2f456d1bd6a0fdf228aa1b9")
    check_xml_file(2, "66179ca44f1e93d8df62e2b88cbea732")
    check_xml_file(3, "848caa72f2f456d1bd6a0fdf228aa1b9")
    check_xml_file(4, "abd6675fdf3024a84fc0a1deac147c0d")
    check_xml_file(6, "848caa72f2f456d1bd6a0fdf228aa1b9")
    check_xml_file(7, "848caa72f2f456d1bd6a0fdf228aa1b9")
    check_xml_file(8, "848caa72f2f456d1bd6a0fdf228aa1b9")
    check_xml_file(9, "848caa72f2f456d1bd6a0fdf228aa1b9")
  end

  def test_large_picture
    trace = create(:trace)
    picture = trace.stub :large_picture_name, "#{GPX_IMAGE_DIR}/1.gif" do
      trace.large_picture
    end

    trace = Trace.create
    trace.large_picture = picture
    assert_equal "7c841749e084ee4a5d13f12cd3bef456", md5sum(File.new(trace.large_picture_name))
    assert_equal picture, trace.large_picture

    trace.destroy
  end

  def test_icon_picture
    trace = create(:trace)
    picture = trace.stub :icon_picture_name, "#{GPX_IMAGE_DIR}/1_icon.gif" do
      trace.icon_picture
    end

    trace = Trace.create
    trace.icon_picture = picture
    assert_equal "b47baf22ed0e85d77e808694fad0ee27", md5sum(File.new(trace.icon_picture_name))
    assert_equal picture, trace.icon_picture

    trace.destroy
  end

  private

  def check_query(query, traces)
    traces = traces.map(&:id).sort
    assert_equal traces, query.order(:id).ids
  end

  def check_mime_type(id, mime_type)
    trace = create(:trace)
    trace.stub :trace_name, "#{GPX_TRACE_DIR}/#{id}.gpx" do
      assert_equal mime_type, trace.mime_type
    end
  end

  def check_extension_name(id, extension_name)
    trace = create(:trace)
    trace.stub :trace_name, "#{GPX_TRACE_DIR}/#{id}.gpx" do
      assert_equal extension_name, trace.extension_name
    end
  end

  def check_xml_file(id, md5sum)
    trace = create(:trace)
    trace.stub :trace_name, "#{GPX_TRACE_DIR}/#{id}.gpx" do
      assert_equal md5sum, md5sum(trace.xml_file)
    end
  end

  def trace_valid(attrs, result = true)
    entry = build(:trace)
    entry.assign_attributes(attrs)
    assert_equal result, entry.valid?, "Expected #{attrs.inspect} to be #{result}"
  end

  def md5sum(io)
    io.each_with_object(Digest::MD5.new) { |l, d| d.update(l) }.hexdigest
  end
end
