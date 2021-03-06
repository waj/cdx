var AddItemSearchTestResultTemplate = React.createClass({
  render: function() {
    return (<span>{this.props.item.test_id} - {this.props.item.name} ({this.props.item.device.name})</span>);
  }
});

var AssaysResult = React.createClass({
  // TODO allow assaysLayout so among different test results, the assays results are rendered in the same order and missing ones can be detected.
  render: function() {
    return (
      <span>
        {this.props.assays.map(function(assay) {
           return <AssayResult assay={assay}/>;
        })}
      </span>
    );
  }
});

var AssayResult = React.createClass({
  render: function() {
    var assay = this.props.assay;

    return (
      <span className={"assay-result assay-result-" + assay.result}>
        {assay.name.toUpperCase()}
      </span>);
  }
});

var TestResult = React.createClass({

  render: function() {
    test = this.props.test_result

    var laboratoryName = null;
    if (test.laboratory)
      laboratoryName = test.laboratory.name;

    return (
    <tr>
      <td>{test.name}</td>
      <td><AssaysResult assays={test.assays} /></td>
      <td>{test.sample_entity_id}</td>
      <td>{laboratoryName}</td>
      <td>{test.start_time}</td>
    </tr>);
  }
});

var TestResultsList = React.createClass({
  render: function() {
    return (
      <table className="table">
        <thead>
          <tr>
            <th className="tableheader" colspan="5">Tests</th>
          </tr>
          <tr>
            <th>Test name</th>
            <th>Result</th>
            <th>Sample ID</th>
            <th>Laboratory</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {this.props.testResults.map(function(test_result) {
             return <TestResult key={test_result.uuid} test_result={test_result}/>;
          })}
        </tbody>
      </table>
    );
  }
});
