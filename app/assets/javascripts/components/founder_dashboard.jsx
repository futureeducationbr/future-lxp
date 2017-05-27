class FounderDashboard extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      levels: this.props.levels,
      chores: this.props.chores,
      sessions: this.props.sessions,
      activeTab: 'targets',
      timelineBuilderVisible: false,
      timelineBuilderParams: {
        targetId: null,
        selectedTimelineEventTypeId: null
      }
    };

    this.chooseTab = this.chooseTab.bind(this);
    this.closeTimelineBuilder = this.closeTimelineBuilder.bind(this);
    this.openTimelineBuilder = this.openTimelineBuilder.bind(this);
    this.handleTargetSubmission = this.handleTargetSubmission.bind(this);
  }

  chooseTab(tab) {
    this.setState({activeTab: tab});
  }

  closeTimelineBuilder() {
    this.setState({timelineBuilderVisible: false});
  }

  openTimelineBuilder(targetId, selectedTimelineEventTypeId) {
    let builderParams = {
      targetId: targetId || null,
      selectedTimelineEventTypeId: selectedTimelineEventTypeId || null
    };

    this.setState({timelineBuilderVisible: true, timelineBuilderParams: builderParams});
  }

  pendingCount(targetType) {
    let targets = targetType == 'chores' ? this.state.chores : this.state.sessions;

    return targets.filter(function (target) {
      return target.status === 'pending';
    }).length;
  }

  handleTargetSubmission(targetId) {
    let updatedLevels = $.extend(true, {}, this.state.levels);
    let updateSubmissionStatus = this.updateSubmissionStatus;

    $.each(updatedLevels, function (index, level) {
      $.each(level.target_groups, function (index, targetGroup) {
        targetGroup.targets = updateSubmissionStatus(targetGroup.targets.slice(), targetId);
      })
    });

    let updatedChores = updateSubmissionStatus(this.state.chores.slice(), targetId);
    let updatedSessions = updateSubmissionStatus(this.state.sessions.slice(), targetId);

    this.setState({levels: updatedLevels, chores: updatedChores, sessions: updatedSessions});
  }

  updateSubmissionStatus(targets, targetId) {
    $.each(targets, function (index, target) {
      if (target.id === targetId) {
        target.status = 'submitted';
        return false;
      }
    });
    return targets;
  }

  render() {
    return (
      <div className="founder-dashboard-container p-b-2">
        <FounderDashboardToggleBar selected={ this.state.activeTab } chooseTabCB={ this.chooseTab }
          openTimelineBuilderCB={ this.openTimelineBuilder } pendingChores={ this.pendingCount('chores') }
          pendingSessions={ this.pendingCount('sessions') }
        currentLevel={ this.props.currentLevel }/>

        { this.props.requestedRestartLevel && <FounderDashboardRestartWarning/> }

        { this.state.activeTab === 'targets' &&
        <FounderDashboardTargets currentLevel={ this.props.currentLevel } levels={ this.state.levels }
          openTimelineBuilderCB={ this.openTimelineBuilder } levelUpEligibility={ this.props.levelUpEligibility }
          authenticityToken={ this.props.authenticityToken } iconPaths={ this.props.iconPaths }
          founderDetails={this.props.founderDetails} maxLevelNumber={ this.props.maxLevelNumber } programLevels={ this.props.programLevels}/>
        }

        { this.state.activeTab === 'chores' &&
        <FounderDashboardChores currentLevel={ this.props.currentLevel } chores={ this.state.chores }
          openTimelineBuilderCB={ this.openTimelineBuilder } iconPaths={ this.props.iconPaths }
                                founderDetails={this.props.founderDetails}/>
        }

        { this.state.activeTab === 'sessions' &&
        <FounderDashboardSessions currentLevel={ this.props.currentLevel } sessions={ this.state.sessions }
          sessionTags={ this.props.sessionTags } openTimelineBuilderCB={ this.openTimelineBuilder }
          iconPaths={ this.props.iconPaths } founderDetails={this.props.founderDetails}/>
        }

        { this.state.timelineBuilderVisible &&
        <TimelineBuilder timelineEventTypes={ this.props.timelineEventTypes }
                         facebookShareEligibility={ this.props.facebookShareEligibility } authenticityToken={ this.props.authenticityToken }
          closeTimelineBuilderCB={ this.closeTimelineBuilder } targetId={ this.state.timelineBuilderParams.targetId }
          selectedTimelineEventTypeId={ this.state.timelineBuilderParams.selectedTimelineEventTypeId }
          targetSubmissionCB={ this.handleTargetSubmission }/>
        }
      </div>
    );
  }
}

FounderDashboard.propTypes = {
  currentLevel: React.PropTypes.number,
  levels: React.PropTypes.object,
  chores: React.PropTypes.array,
  sessions: React.PropTypes.array,
  sessionTags: React.PropTypes.array,
  timelineEventTypes: React.PropTypes.object,
  facebookShareEligibility: React.PropTypes.string,
  authenticityToken: React.PropTypes.string,
  levelUpEligibility: React.PropTypes.string,
  iconPaths: React.PropTypes.object,
  founderDetails: React.PropTypes.array,
  maxLevelNumber: React.PropTypes.number,
  programLevels: React.PropTypes.object
};